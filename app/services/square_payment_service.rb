require 'squareup'

class SquarePaymentService
  def initialize(payment_integration)
    @integration = payment_integration
    configure_square
  end

  def create_payment(amount, options = {})
    begin
      # Square amounts are in the smallest currency unit (e.g., cents for USD, yen for JPY)
      amount_money = {
        amount: amount,
        currency: (options[:currency] || 'JPY').upcase
      }

      request_body = {
        source_id: options[:payment_method] || options[:source_id],
        amount_money: amount_money,
        idempotency_key: generate_idempotency_key,
        reference_id: options[:reference_id] || generate_reference_id,
        note: options[:description] || "Payment for #{@integration.festival&.name}",
        app_fee_money: calculate_app_fee(amount, options),
        autocomplete: options[:autocomplete] != false,
        location_id: @integration.location_id,
        buyer_email_address: options[:buyer_email],
        billing_address: build_billing_address(options[:billing_address]),
        shipping_address: build_shipping_address(options[:shipping_address])
      }

      response = @payments_api.create_payment(body: request_body)

      if response.success?
        payment = response.data.payment
        {
          success: true,
          transaction_id: payment.id,
          status: payment.status.downcase,
          amount: payment.amount_money.amount,
          currency: payment.amount_money.currency,
          receipt_number: payment.receipt_number,
          receipt_url: payment.receipt_url,
          created_at: payment.created_at
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def create_payment_intent(amount, options = {})
    # Square doesn't have a direct equivalent to payment intents
    # Instead, we'll create a payment with delayed_capture
    begin
      amount_money = {
        amount: amount,
        currency: (options[:currency] || 'JPY').upcase
      }

      request_body = {
        source_id: options[:payment_method] || 'CASH', # Placeholder for now
        amount_money: amount_money,
        idempotency_key: generate_idempotency_key,
        reference_id: options[:reference_id] || generate_reference_id,
        note: options[:description] || "Payment intent for #{@integration.festival&.name}",
        autocomplete: false, # This creates an authorized but not captured payment
        location_id: @integration.location_id,
        delay_action: 'CANCEL', # Auto-cancel if not captured within timeframe
        delay_duration: 'PT24H' # 24 hours
      }

      # For payment intents, we'll use Terminal API for in-person payments
      # or return information for online card processing
      {
        success: true,
        payment_intent_id: generate_reference_id,
        client_secret: "sq_#{generate_idempotency_key}",
        status: 'requires_payment_method',
        amount: amount,
        currency: (options[:currency] || 'JPY').upcase,
        application_id: @client.config.square_application_id
      }
    rescue => error
      {
        success: false,
        error: error.message,
        error_type: 'square_error'
      }
    end
  end

  def create_refund(transaction_id, amount = nil, reason = nil)
    begin
      # First, get the original payment to determine refund amount
      payment_response = @payments_api.get_payment(payment_id: transaction_id)
      
      unless payment_response.success?
        return {
          success: false,
          error: 'Original payment not found',
          error_code: 'PAYMENT_NOT_FOUND'
        }
      end

      original_payment = payment_response.data.payment
      refund_amount = amount || original_payment.amount_money.amount

      amount_money = {
        amount: refund_amount,
        currency: original_payment.amount_money.currency
      }

      request_body = {
        idempotency_key: generate_idempotency_key,
        amount_money: amount_money,
        payment_id: transaction_id,
        reason: reason || 'Refund requested by customer',
        location_id: @integration.location_id
      }

      response = @refunds_api.refund_payment(body: request_body)

      if response.success?
        refund = response.data.refund
        {
          success: true,
          refund_id: refund.id,
          status: refund.status.downcase,
          amount: refund.amount_money.amount,
          reason: refund.reason,
          created_at: refund.created_at
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def get_payment_methods
    begin
      # Square doesn't store payment methods in the same way as Stripe
      # This would typically involve Card on File API for stored cards
      response = @customers_api.list_customers(
        limit: 100,
        sort_field: 'CREATED_AT',
        sort_order: 'DESC'
      )

      if response.success? && response.data.customers
        payment_methods = []
        
        response.data.customers.each do |customer|
          if customer.cards && customer.cards.any?
            customer.cards.each do |card|
              payment_methods << {
                id: card.id,
                type: 'card',
                brand: card.card_brand,
                last4: card.last_4,
                exp_month: card.exp_month,
                exp_year: card.exp_year,
                fingerprint: card.fingerprint,
                customer_id: customer.id
              }
            end
          end
        end
        
        payment_methods
      else
        []
      end
    rescue => error
      Rails.logger.error "Failed to fetch Square payment methods: #{error.message}"
      []
    end
  end

  def create_customer(options = {})
    begin
      request_body = {
        given_name: options[:first_name] || options[:name]&.split(' ')&.first,
        family_name: options[:last_name] || options[:name]&.split(' ')&.last,
        email_address: options[:email],
        phone_number: options[:phone],
        note: options[:note] || "Customer for #{@integration.festival&.name}",
        reference_id: options[:reference_id]
      }

      response = @customers_api.create_customer(body: request_body)

      if response.success?
        customer = response.data.customer
        {
          success: true,
          customer_id: customer.id,
          email: customer.email_address,
          name: "#{customer.given_name} #{customer.family_name}".strip,
          phone: customer.phone_number,
          reference_id: customer.reference_id
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def create_subscription(customer_id, plan_id, options = {})
    begin
      # Square Subscriptions API
      request_body = {
        idempotency_key: generate_idempotency_key,
        location_id: @integration.location_id,
        plan_id: plan_id,
        customer_id: customer_id,
        card_id: options[:card_id],
        start_date: options[:start_date] || Date.current.iso8601,
        tax_percentage: options[:tax_percentage],
        price_override_money: options[:price_override] ? {
          amount: options[:price_override],
          currency: options[:currency] || 'JPY'
        } : nil,
        timezone: options[:timezone] || 'Asia/Tokyo'
      }

      response = @subscriptions_api.create_subscription(body: request_body)

      if response.success?
        subscription = response.data.subscription
        {
          success: true,
          subscription_id: subscription.id,
          status: subscription.status.downcase,
          plan_id: subscription.plan_id,
          start_date: subscription.start_date,
          charged_through_date: subscription.charged_through_date,
          created_at: subscription.created_at
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def cancel_subscription(subscription_id, options = {})
    begin
      response = @subscriptions_api.cancel_subscription(
        subscription_id: subscription_id,
        body: {}
      )

      if response.success?
        subscription = response.data.subscription
        {
          success: true,
          subscription_id: subscription.id,
          status: subscription.status.downcase,
          canceled_date: subscription.canceled_date
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def setup_webhook(webhook_url)
    begin
      request_body = {
        idempotency_key: generate_idempotency_key,
        subscription: {
          name: "Festival Platform Webhook",
          event_types: webhook_events,
          notification_url: webhook_url,
          api_version: @client.config.square_api_version
        }
      }

      response = @webhook_subscriptions_api.create_webhook_subscription(body: request_body)

      if response.success?
        webhook = response.data.subscription
        {
          success: true,
          webhook_id: webhook.id,
          webhook_secret: webhook.signature_key,
          url: webhook.notification_url,
          enabled_events: webhook.event_types
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def verify_webhook_signature(payload, signature, webhook_secret)
    begin
      # Square webhook signature verification
      expected_signature = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        webhook_secret,
        "#{@webhook_notification_url}#{payload}"
      )
      
      signature == expected_signature
    rescue => error
      Rails.logger.error "Square webhook signature verification failed: #{error.message}"
      false
    end
  end

  def process_webhook(payload)
    begin
      event = JSON.parse(payload)
      
      case event['type']
      when 'payment.updated'
        handle_payment_updated(event['data']['object'])
      when 'refund.updated'
        handle_refund_updated(event['data']['object'])
      when 'subscription.updated'
        handle_subscription_updated(event['data']['object'])
      when 'invoice.updated'
        handle_invoice_updated(event['data']['object'])
      when 'customer.updated'
        handle_customer_updated(event['data']['object'])
      else
        Rails.logger.info "Unhandled Square webhook event: #{event['type']}"
        { success: true, message: 'Event received but not processed' }
      end
    rescue JSON::ParserError => error
      { success: false, error: 'Invalid JSON payload' }
    rescue => error
      Rails.logger.error "Square webhook processing error: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def test_connection
    begin
      response = @locations_api.list_locations
      
      if response.success?
        { success: true, message: 'Square connection successful' }
      else
        { success: false, message: 'Square API authentication failed' }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  def get_transaction_details(transaction_id)
    begin
      response = @payments_api.get_payment(payment_id: transaction_id)

      if response.success?
        payment = response.data.payment
        {
          success: true,
          transaction_id: payment.id,
          amount: payment.amount_money.amount,
          currency: payment.amount_money.currency,
          status: payment.status.downcase,
          created_at: payment.created_at,
          updated_at: payment.updated_at,
          reference_id: payment.reference_id,
          note: payment.note,
          receipt_number: payment.receipt_number,
          receipt_url: payment.receipt_url,
          location_id: payment.location_id
        }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def get_locations
    begin
      response = @locations_api.list_locations

      if response.success?
        locations = response.data.locations.map do |location|
          {
            id: location.id,
            name: location.name,
            address: format_address(location.address),
            status: location.status,
            capabilities: location.capabilities,
            country: location.country,
            language_code: location.language_code,
            currency: location.currency,
            timezone: location.timezone
          }
        end
        
        { success: true, locations: locations }
      else
        handle_square_errors(response.errors)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  private

  def configure_square
    @client = SquareConnect::ApiClient.new
    @client.config.access_token = @integration.api_key
    @client.config.environment = @integration.environment || 'sandbox'
    
    # Initialize API instances
    @payments_api = SquareConnect::PaymentsApi.new(@client)
    @refunds_api = SquareConnect::RefundsApi.new(@client)
    @customers_api = SquareConnect::CustomersApi.new(@client)
    @subscriptions_api = SquareConnect::SubscriptionsApi.new(@client)
    @webhook_subscriptions_api = SquareConnect::WebhookSubscriptionsApi.new(@client)
    @locations_api = SquareConnect::LocationsApi.new(@client)
  end

  def generate_idempotency_key
    "#{@integration.id}_#{Time.current.to_i}_#{SecureRandom.hex(8)}"
  end

  def generate_reference_id
    "festival_#{@integration.festival_id}_#{SecureRandom.hex(6)}"
  end

  def calculate_app_fee(amount, options)
    return nil unless options[:app_fee_amount]
    
    {
      amount: options[:app_fee_amount],
      currency: options[:currency] || 'JPY'
    }
  end

  def build_billing_address(address_data)
    return nil unless address_data
    
    {
      address_line_1: address_data[:line1],
      address_line_2: address_data[:line2],
      locality: address_data[:city],
      administrative_district_level_1: address_data[:state],
      postal_code: address_data[:postal_code],
      country: address_data[:country] || 'JP',
      first_name: address_data[:first_name],
      last_name: address_data[:last_name]
    }
  end

  def build_shipping_address(address_data)
    return nil unless address_data
    
    {
      address_line_1: address_data[:line1],
      address_line_2: address_data[:line2],
      locality: address_data[:city],
      administrative_district_level_1: address_data[:state],
      postal_code: address_data[:postal_code],
      country: address_data[:country] || 'JP',
      first_name: address_data[:first_name],
      last_name: address_data[:last_name]
    }
  end

  def format_address(address)
    return nil unless address
    
    parts = [
      address.address_line_1,
      address.address_line_2,
      address.locality,
      address.administrative_district_level_1,
      address.postal_code
    ].compact
    
    parts.join(', ')
  end

  def webhook_events
    [
      'payment.updated',
      'refund.updated',
      'subscription.updated',
      'invoice.updated',
      'customer.updated'
    ]
  end

  def handle_payment_updated(payment)
    {
      success: true,
      transaction_id: payment['id'],
      status: payment['status'].downcase,
      event_type: 'payment_updated',
      amount: payment['amount_money']['amount'],
      currency: payment['amount_money']['currency']
    }
  end

  def handle_refund_updated(refund)
    {
      success: true,
      refund_id: refund['id'],
      transaction_id: refund['payment_id'],
      status: refund['status'].downcase,
      event_type: 'refund_updated',
      amount: refund['amount_money']['amount'],
      currency: refund['amount_money']['currency']
    }
  end

  def handle_subscription_updated(subscription)
    {
      success: true,
      subscription_id: subscription['id'],
      status: subscription['status'].downcase,
      event_type: 'subscription_updated'
    }
  end

  def handle_invoice_updated(invoice)
    {
      success: true,
      invoice_id: invoice['id'],
      subscription_id: invoice['subscription_id'],
      status: invoice['status'].downcase,
      event_type: 'invoice_updated'
    }
  end

  def handle_customer_updated(customer)
    {
      success: true,
      customer_id: customer['id'],
      event_type: 'customer_updated'
    }
  end

  def handle_square_errors(errors)
    error_messages = errors.map { |error| error.detail }.join('; ')
    error_codes = errors.map { |error| error.code }.join(', ')
    
    {
      success: false,
      error: error_messages,
      error_code: error_codes,
      error_type: 'square_api_error'
    }
  end

  def handle_unknown_error(error)
    Rails.logger.error "Unknown Square error: #{error.message}"
    {
      success: false,
      error: 'An unexpected error occurred',
      error_type: 'unknown_error'
    }
  end
end