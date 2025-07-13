require 'paypal-sdk-rest'

class PaypalPaymentService
  include PayPal::SDK::REST

  def initialize(payment_integration)
    @integration = payment_integration
    configure_paypal
  end

  def create_payment(amount, options = {})
    begin
      # Convert amount to PayPal format (2 decimal places for most currencies)
      formatted_amount = format_amount(amount, options[:currency] || 'JPY')
      
      payment = Payment.new({
        intent: 'sale',
        payer: build_payer(options),
        redirect_urls: build_redirect_urls(options),
        transactions: [{
          item_list: build_item_list(options),
          amount: {
            total: formatted_amount,
            currency: (options[:currency] || 'JPY').upcase,
            details: build_amount_details(options)
          },
          description: options[:description] || "Payment for #{@integration.festival&.name}",
          invoice_number: options[:invoice_number] || generate_invoice_number,
          payment_options: {
            allowed_payment_method: 'INSTANT_FUNDING_SOURCE'
          },
          note_to_payer: options[:note_to_payer],
          custom: build_custom_data(options)
        }]
      })

      if payment.create
        {
          success: true,
          transaction_id: payment.id,
          status: payment.state,
          approval_url: payment.links.find { |link| link.rel == 'approval_url' }&.href,
          execute_url: payment.links.find { |link| link.rel == 'execute' }&.href,
          amount: formatted_amount,
          currency: (options[:currency] || 'JPY').upcase,
          created_time: payment.create_time
        }
      else
        handle_paypal_errors(payment.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def execute_payment(payment_id, payer_id)
    begin
      payment = Payment.find(payment_id)
      
      if payment.execute(payer_id: payer_id)
        {
          success: true,
          transaction_id: payment.id,
          status: payment.state,
          payer_id: payer_id,
          amount: payment.transactions.first.amount.total,
          currency: payment.transactions.first.amount.currency,
          sale_id: payment.transactions.first.related_resources.first.sale&.id
        }
      else
        handle_paypal_errors(payment.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def create_payment_intent(amount, options = {})
    # PayPal doesn't have direct payment intents like Stripe
    # We'll create a payment and return the approval URL
    result = create_payment(amount, options.merge(intent: 'authorize'))
    
    if result[:success]
      {
        success: true,
        payment_intent_id: result[:transaction_id],
        client_secret: result[:approval_url],
        status: 'requires_action',
        amount: amount,
        currency: (options[:currency] || 'JPY').upcase,
        approval_url: result[:approval_url]
      }
    else
      result
    end
  end

  def create_refund(transaction_id, amount = nil, reason = nil)
    begin
      # First find the sale from the payment
      payment = Payment.find(transaction_id)
      sale = payment.transactions.first.related_resources.first.sale
      
      unless sale
        return {
          success: false,
          error: 'Sale not found for this payment',
          error_code: 'SALE_NOT_FOUND'
        }
      end

      refund_amount = amount ? format_amount(amount, sale.amount.currency) : sale.amount.total
      
      refund = Refund.new({
        amount: {
          total: refund_amount,
          currency: sale.amount.currency
        },
        description: reason || 'Refund requested by customer',
        reason: reason || 'Customer requested refund',
        invoice_number: generate_invoice_number
      })

      if sale.refund(refund)
        {
          success: true,
          refund_id: refund.id,
          status: refund.state,
          amount: refund.amount.total,
          currency: refund.amount.currency,
          reason: refund.reason,
          created_time: refund.create_time
        }
      else
        handle_paypal_errors(refund.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def get_payment_methods
    begin
      # PayPal doesn't store payment methods in the traditional sense
      # Instead, we can get stored funding instruments via the PayPal API
      # For now, return basic PayPal payment options
      [
        {
          id: 'paypal',
          type: 'paypal_account',
          brand: 'PayPal',
          description: 'PayPal Account',
          capabilities: ['payments', 'refunds']
        },
        {
          id: 'paypal_credit',
          type: 'paypal_credit',
          brand: 'PayPal Credit',
          description: 'PayPal Credit',
          capabilities: ['payments']
        }
      ]
    rescue => error
      Rails.logger.error "Failed to fetch PayPal payment methods: #{error.message}"
      []
    end
  end

  def create_billing_plan(options = {})
    begin
      plan = Plan.new({
        name: options[:name] || "#{@integration.festival&.name} Subscription Plan",
        description: options[:description] || "Recurring payment plan",
        type: options[:type] || 'INFINITE',
        payment_definitions: [{
          name: options[:payment_name] || 'Regular Payment',
          type: 'REGULAR',
          frequency: options[:frequency] || 'MONTH',
          frequency_interval: options[:frequency_interval] || '1',
          amount: {
            value: format_amount(options[:amount], options[:currency]),
            currency: (options[:currency] || 'JPY').upcase
          },
          cycles: options[:cycles] || '0', # 0 for infinite
          charge_models: [{
            type: 'TAX',
            amount: {
              value: format_amount(options[:tax_amount] || 0, options[:currency]),
              currency: (options[:currency] || 'JPY').upcase
            }
          }]
        }],
        merchant_preferences: {
          return_url: options[:return_url] || "#{Rails.application.config.frontend_url}/payment/success",
          cancel_url: options[:cancel_url] || "#{Rails.application.config.frontend_url}/payment/cancel",
          auto_bill_amount: 'YES',
          initial_fail_amount_action: 'CONTINUE',
          max_fail_attempts: '3',
          setup_fee: {
            value: format_amount(options[:setup_fee] || 0, options[:currency]),
            currency: (options[:currency] || 'JPY').upcase
          }
        }
      })

      if plan.create
        # Activate the plan
        if plan.activate
          {
            success: true,
            plan_id: plan.id,
            state: plan.state,
            name: plan.name,
            type: plan.type
          }
        else
          handle_paypal_errors(plan.error)
        end
      else
        handle_paypal_errors(plan.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def create_subscription(plan_id, options = {})
    begin
      agreement = Agreement.new({
        name: options[:name] || "#{@integration.festival&.name} Subscription",
        description: options[:description] || "Subscription agreement",
        start_date: (options[:start_date] || 1.day.from_now).iso8601,
        plan: {
          id: plan_id
        },
        payer: {
          payment_method: 'paypal'
        },
        shipping_address: build_shipping_address(options[:shipping_address])
      })

      if agreement.create
        {
          success: true,
          subscription_id: agreement.id,
          approval_url: agreement.links.find { |link| link.rel == 'approval_url' }&.href,
          status: agreement.state,
          start_date: agreement.start_date
        }
      else
        handle_paypal_errors(agreement.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def cancel_subscription(subscription_id, options = {})
    begin
      agreement = Agreement.find(subscription_id)
      
      cancel_note = {
        note: options[:reason] || 'Subscription canceled by customer'
      }

      if agreement.cancel(cancel_note)
        {
          success: true,
          subscription_id: agreement.id,
          status: 'Cancelled',
          canceled_at: Time.current.iso8601
        }
      else
        handle_paypal_errors(agreement.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def setup_webhook(webhook_url)
    begin
      webhook = Webhook.new({
        url: webhook_url,
        event_types: webhook_events.map { |event| { name: event } }
      })

      if webhook.create
        {
          success: true,
          webhook_id: webhook.id,
          webhook_secret: nil, # PayPal uses certificate verification
          url: webhook.url,
          enabled_events: webhook.event_types.map(&:name)
        }
      else
        handle_paypal_errors(webhook.error)
      end
    rescue => error
      handle_unknown_error(error)
    end
  end

  def verify_webhook_signature(payload, signature, webhook_secret = nil)
    begin
      # PayPal webhook verification is different - it uses certificate verification
      # For now, we'll implement a basic verification
      # In production, you should verify the certificate chain
      event = JSON.parse(payload)
      
      # Basic verification - check if required fields are present
      required_fields = ['id', 'create_time', 'resource_type', 'event_type']
      required_fields.all? { |field| event[field].present? }
    rescue JSON::ParserError
      false
    rescue => error
      Rails.logger.error "PayPal webhook signature verification failed: #{error.message}"
      false
    end
  end

  def process_webhook(payload)
    begin
      event = JSON.parse(payload)
      
      case event['event_type']
      when 'PAYMENT.SALE.COMPLETED'
        handle_payment_completed(event['resource'])
      when 'PAYMENT.SALE.DENIED'
        handle_payment_denied(event['resource'])
      when 'PAYMENT.SALE.REFUNDED'
        handle_payment_refunded(event['resource'])
      when 'BILLING.SUBSCRIPTION.ACTIVATED'
        handle_subscription_activated(event['resource'])
      when 'BILLING.SUBSCRIPTION.CANCELLED'
        handle_subscription_cancelled(event['resource'])
      when 'BILLING.SUBSCRIPTION.PAYMENT.FAILED'
        handle_subscription_payment_failed(event['resource'])
      else
        Rails.logger.info "Unhandled PayPal webhook event: #{event['event_type']}"
        { success: true, message: 'Event received but not processed' }
      end
    rescue JSON::ParserError => error
      { success: false, error: 'Invalid JSON payload' }
    rescue => error
      Rails.logger.error "PayPal webhook processing error: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def test_connection
    begin
      # Test by creating a minimal plan and immediately deleting it
      test_plan = Plan.new({
        name: 'Test Connection Plan',
        description: 'Test plan for connection verification',
        type: 'FIXED',
        payment_definitions: [{
          name: 'Test Payment',
          type: 'REGULAR',
          frequency: 'MONTH',
          frequency_interval: '1',
          amount: {
            value: '10.00',
            currency: 'JPY'
          },
          cycles: '1'
        }],
        merchant_preferences: {
          return_url: 'http://example.com/return',
          cancel_url: 'http://example.com/cancel'
        }
      })

      if test_plan.create
        # Clean up the test plan
        test_plan.replace([{ op: 'replace', path: '/', value: { state: 'INACTIVE' } }])
        { success: true, message: 'PayPal connection successful' }
      else
        { success: false, message: 'PayPal connection failed' }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  def get_transaction_details(transaction_id)
    begin
      payment = Payment.find(transaction_id)
      
      {
        success: true,
        transaction_id: payment.id,
        status: payment.state,
        intent: payment.intent,
        created_time: payment.create_time,
        update_time: payment.update_time,
        transactions: payment.transactions.map do |transaction|
          {
            amount: transaction.amount.total,
            currency: transaction.amount.currency,
            description: transaction.description,
            invoice_number: transaction.invoice_number,
            custom: transaction.custom,
            related_resources: transaction.related_resources.map do |resource|
              if resource.sale
                {
                  type: 'sale',
                  id: resource.sale.id,
                  state: resource.sale.state,
                  amount: resource.sale.amount.total,
                  currency: resource.sale.amount.currency,
                  payment_mode: resource.sale.payment_mode,
                  protection_eligibility: resource.sale.protection_eligibility
                }
              end
            end.compact
          }
        end
      }
    rescue => error
      handle_unknown_error(error)
    end
  end

  private

  def configure_paypal
    PayPal::SDK.configure({
      mode: @integration.environment || 'sandbox',
      client_id: @integration.api_key,
      client_secret: @integration.api_secret,
      ssl_options: {
        ca_file: nil,
        verify_mode: OpenSSL::SSL::VERIFY_PEER
      }
    })
  end

  def format_amount(amount, currency = 'JPY')
    # PayPal expects different decimal places for different currencies
    case currency.upcase
    when 'JPY', 'KRW'
      amount.to_i.to_s # No decimal places for JPY
    else
      sprintf('%.2f', amount.to_f / 100) # Convert from cents to dollars for most currencies
    end
  end

  def build_payer(options)
    payer_info = {
      payment_method: 'paypal'
    }

    if options[:payer_info]
      payer_info[:payer_info] = {
        email: options[:payer_info][:email],
        first_name: options[:payer_info][:first_name],
        last_name: options[:payer_info][:last_name],
        payer_id: options[:payer_info][:payer_id],
        phone: options[:payer_info][:phone],
        shipping_address: build_shipping_address(options[:payer_info][:shipping_address]),
        billing_address: build_billing_address(options[:payer_info][:billing_address])
      }
    end

    payer_info
  end

  def build_redirect_urls(options)
    {
      return_url: options[:return_url] || "#{Rails.application.config.frontend_url}/payment/success",
      cancel_url: options[:cancel_url] || "#{Rails.application.config.frontend_url}/payment/cancel"
    }
  end

  def build_item_list(options)
    return {} unless options[:items]

    {
      items: options[:items].map do |item|
        {
          name: item[:name],
          description: item[:description],
          quantity: item[:quantity].to_s,
          price: format_amount(item[:price], item[:currency]),
          currency: (item[:currency] || 'JPY').upcase,
          sku: item[:sku]
        }
      end,
      shipping_address: build_shipping_address(options[:shipping_address])
    }
  end

  def build_amount_details(options)
    return {} unless options[:amount_details]

    {
      subtotal: format_amount(options[:amount_details][:subtotal], options[:currency]),
      tax: format_amount(options[:amount_details][:tax] || 0, options[:currency]),
      shipping: format_amount(options[:amount_details][:shipping] || 0, options[:currency]),
      handling_fee: format_amount(options[:amount_details][:handling_fee] || 0, options[:currency]),
      shipping_discount: format_amount(options[:amount_details][:shipping_discount] || 0, options[:currency]),
      insurance: format_amount(options[:amount_details][:insurance] || 0, options[:currency])
    }
  end

  def build_shipping_address(address_data)
    return {} unless address_data

    {
      recipient_name: address_data[:recipient_name],
      line1: address_data[:line1],
      line2: address_data[:line2],
      city: address_data[:city],
      country_code: address_data[:country_code] || 'JP',
      postal_code: address_data[:postal_code],
      state: address_data[:state],
      phone: address_data[:phone]
    }
  end

  def build_billing_address(address_data)
    return {} unless address_data

    {
      line1: address_data[:line1],
      line2: address_data[:line2],
      city: address_data[:city],
      country_code: address_data[:country_code] || 'JP',
      postal_code: address_data[:postal_code],
      state: address_data[:state]
    }
  end

  def build_custom_data(options)
    custom_data = {
      integration_id: @integration.id,
      user_id: @integration.user_id
    }
    
    custom_data[:festival_id] = @integration.festival_id if @integration.festival_id
    custom_data.merge!(options[:custom] || {})
    
    JSON.generate(custom_data)
  end

  def generate_invoice_number
    "INV-#{@integration.id}-#{Time.current.to_i}-#{SecureRandom.hex(4)}"
  end

  def webhook_events
    [
      'PAYMENT.SALE.COMPLETED',
      'PAYMENT.SALE.DENIED',
      'PAYMENT.SALE.REFUNDED',
      'BILLING.SUBSCRIPTION.ACTIVATED',
      'BILLING.SUBSCRIPTION.CANCELLED',
      'BILLING.SUBSCRIPTION.SUSPENDED',
      'BILLING.SUBSCRIPTION.PAYMENT.FAILED',
      'BILLING.SUBSCRIPTION.PAYMENT.COMPLETED'
    ]
  end

  def handle_payment_completed(sale)
    {
      success: true,
      transaction_id: sale['parent_payment'],
      sale_id: sale['id'],
      status: 'completed',
      event_type: 'payment_completed',
      amount: sale['amount']['total'],
      currency: sale['amount']['currency']
    }
  end

  def handle_payment_denied(sale)
    {
      success: true,
      transaction_id: sale['parent_payment'],
      sale_id: sale['id'],
      status: 'denied',
      event_type: 'payment_denied',
      amount: sale['amount']['total'],
      currency: sale['amount']['currency']
    }
  end

  def handle_payment_refunded(refund)
    {
      success: true,
      refund_id: refund['id'],
      transaction_id: refund['parent_payment'],
      status: 'refunded',
      event_type: 'payment_refunded',
      amount: refund['amount']['total'],
      currency: refund['amount']['currency']
    }
  end

  def handle_subscription_activated(subscription)
    {
      success: true,
      subscription_id: subscription['id'],
      status: 'active',
      event_type: 'subscription_activated'
    }
  end

  def handle_subscription_cancelled(subscription)
    {
      success: true,
      subscription_id: subscription['id'],
      status: 'cancelled',
      event_type: 'subscription_cancelled'
    }
  end

  def handle_subscription_payment_failed(payment)
    {
      success: true,
      subscription_id: payment['billing_agreement_id'],
      status: 'payment_failed',
      event_type: 'subscription_payment_failed',
      amount: payment['amount']['total'],
      currency: payment['amount']['currency']
    }
  end

  def handle_paypal_errors(error_details)
    error_message = if error_details.is_a?(Hash)
                     error_details['message'] || 'PayPal API error'
                   else
                     error_details.to_s
                   end

    {
      success: false,
      error: error_message,
      error_type: 'paypal_api_error',
      error_details: error_details
    }
  end

  def handle_unknown_error(error)
    Rails.logger.error "Unknown PayPal error: #{error.message}"
    {
      success: false,
      error: 'An unexpected error occurred',
      error_type: 'unknown_error'
    }
  end
end