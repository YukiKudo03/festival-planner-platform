class StripePaymentService
  def initialize(payment_integration)
    @integration = payment_integration
    @stripe_client = Stripe
    configure_stripe
  end

  def create_payment(amount, options = {})
    begin
      payment_intent = @stripe_client::PaymentIntent.create({
        amount: amount,
        currency: options[:currency] || "jpy",
        payment_method: options[:payment_method],
        customer: options[:customer_id],
        metadata: build_metadata(options),
        description: options[:description] || "Payment for #{@integration.festival&.name}",
        receipt_email: options[:receipt_email],
        setup_future_usage: options[:save_payment_method] ? "on_session" : nil
      })

      {
        success: true,
        transaction_id: payment_intent.id,
        status: payment_intent.status,
        client_secret: payment_intent.client_secret,
        amount: payment_intent.amount,
        currency: payment_intent.currency,
        payment_url: generate_payment_url(payment_intent)
      }
    rescue Stripe::CardError => error
      handle_card_error(error)
    rescue Stripe::InvalidRequestError => error
      handle_invalid_request_error(error)
    rescue Stripe::AuthenticationError => error
      handle_authentication_error(error)
    rescue Stripe::APIConnectionError => error
      handle_connection_error(error)
    rescue Stripe::StripeError => error
      handle_generic_stripe_error(error)
    rescue => error
      handle_unknown_error(error)
    end
  end

  def create_payment_intent(amount, options = {})
    begin
      payment_intent = @stripe_client::PaymentIntent.create({
        amount: amount,
        currency: options[:currency] || "jpy",
        customer: options[:customer_id],
        metadata: build_metadata(options),
        description: options[:description] || "Payment intent for #{@integration.festival&.name}",
        automatic_payment_methods: {
          enabled: true
        }
      })

      {
        success: true,
        payment_intent_id: payment_intent.id,
        client_secret: payment_intent.client_secret,
        status: payment_intent.status,
        amount: payment_intent.amount,
        currency: payment_intent.currency
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  def create_refund(transaction_id, amount = nil, reason = nil)
    begin
      refund_params = {
        payment_intent: transaction_id,
        reason: reason || "requested_by_customer"
      }
      refund_params[:amount] = amount if amount.present?

      refund = @stripe_client::Refund.create(refund_params)

      {
        success: true,
        refund_id: refund.id,
        status: refund.status,
        amount: refund.amount,
        reason: refund.reason
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  def get_payment_methods
    begin
      payment_methods = @stripe_client::PaymentMethod.list({
        customer: @integration.stripe_customer_id,
        type: "card"
      })

      payment_methods.data.map do |pm|
        {
          id: pm.id,
          type: pm.type,
          brand: pm.card&.brand,
          last4: pm.card&.last4,
          exp_month: pm.card&.exp_month,
          exp_year: pm.card&.exp_year,
          fingerprint: pm.card&.fingerprint
        }
      end
    rescue Stripe::StripeError => error
      Rails.logger.error "Failed to fetch Stripe payment methods: #{error.message}"
      []
    end
  end

  def create_customer(options = {})
    begin
      customer = @stripe_client::Customer.create({
        email: options[:email],
        name: options[:name],
        phone: options[:phone],
        metadata: build_metadata(options)
      })

      {
        success: true,
        customer_id: customer.id,
        email: customer.email,
        name: customer.name
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  def create_subscription(customer_id, price_id, options = {})
    begin
      subscription = @stripe_client::Subscription.create({
        customer: customer_id,
        items: [ { price: price_id } ],
        metadata: build_metadata(options),
        trial_period_days: options[:trial_days],
        payment_behavior: "default_incomplete",
        payment_settings: { save_default_payment_method: "on_subscription" },
        expand: [ "latest_invoice.payment_intent" ]
      })

      {
        success: true,
        subscription_id: subscription.id,
        status: subscription.status,
        client_secret: subscription.latest_invoice.payment_intent.client_secret,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  def cancel_subscription(subscription_id, options = {})
    begin
      subscription = @stripe_client::Subscription.update(subscription_id, {
        cancel_at_period_end: options[:cancel_at_period_end] || false
      })

      if options[:cancel_immediately]
        subscription = @stripe_client::Subscription.delete(subscription_id)
      end

      {
        success: true,
        subscription_id: subscription.id,
        status: subscription.status,
        canceled_at: subscription.canceled_at,
        current_period_end: subscription.current_period_end
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  def setup_webhook(webhook_url)
    begin
      webhook_endpoint = @stripe_client::WebhookEndpoint.create({
        url: webhook_url,
        enabled_events: webhook_events
      })

      {
        success: true,
        webhook_id: webhook_endpoint.id,
        webhook_secret: webhook_endpoint.secret,
        url: webhook_endpoint.url,
        enabled_events: webhook_endpoint.enabled_events
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  def verify_webhook_signature(payload, signature, webhook_secret)
    begin
      @stripe_client::Webhook.construct_event(payload, signature, webhook_secret)
      true
    rescue Stripe::SignatureVerificationError
      false
    end
  end

  def process_webhook(payload)
    begin
      event = JSON.parse(payload)

      case event["type"]
      when "payment_intent.succeeded"
        handle_payment_succeeded(event["data"]["object"])
      when "payment_intent.payment_failed"
        handle_payment_failed(event["data"]["object"])
      when "payment_intent.canceled"
        handle_payment_canceled(event["data"]["object"])
      when "invoice.payment_succeeded"
        handle_invoice_payment_succeeded(event["data"]["object"])
      when "invoice.payment_failed"
        handle_invoice_payment_failed(event["data"]["object"])
      when "customer.subscription.created"
        handle_subscription_created(event["data"]["object"])
      when "customer.subscription.updated"
        handle_subscription_updated(event["data"]["object"])
      when "customer.subscription.deleted"
        handle_subscription_deleted(event["data"]["object"])
      else
        Rails.logger.info "Unhandled Stripe webhook event: #{event['type']}"
        { success: true, message: "Event received but not processed" }
      end
    rescue JSON::ParserError => error
      { success: false, error: "Invalid JSON payload" }
    rescue => error
      Rails.logger.error "Stripe webhook processing error: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def test_connection
    begin
      @stripe_client::Account.retrieve
      { success: true, message: "Stripe connection successful" }
    rescue Stripe::AuthenticationError => error
      { success: false, message: "Invalid API key" }
    rescue Stripe::APIConnectionError => error
      { success: false, message: "Network connection failed" }
    rescue Stripe::StripeError => error
      { success: false, message: error.message }
    end
  end

  def get_transaction_details(transaction_id)
    begin
      payment_intent = @stripe_client::PaymentIntent.retrieve(transaction_id)

      {
        success: true,
        transaction_id: payment_intent.id,
        amount: payment_intent.amount,
        currency: payment_intent.currency,
        status: payment_intent.status,
        created: payment_intent.created,
        description: payment_intent.description,
        customer: payment_intent.customer,
        payment_method: payment_intent.payment_method,
        receipt_email: payment_intent.receipt_email,
        metadata: payment_intent.metadata.to_h
      }
    rescue Stripe::StripeError => error
      {
        success: false,
        error: error.message,
        error_code: error.code
      }
    end
  end

  private

  def configure_stripe
    @stripe_client.api_key = @integration.api_key
    @stripe_client.api_version = "2023-10-16"
  end

  def build_metadata(options)
    metadata = {
      integration_id: @integration.id.to_s,
      user_id: @integration.user_id.to_s
    }

    metadata[:festival_id] = @integration.festival_id.to_s if @integration.festival_id
    metadata.merge!(options[:metadata] || {})

    # Stripe metadata values must be strings and max 500 chars each
    metadata.transform_values { |v| v.to_s.slice(0, 500) }
  end

  def generate_payment_url(payment_intent)
    # This would typically link to your payment form with the client_secret
    # For now, return a placeholder
    "#{Rails.application.config.frontend_url}/payments/#{payment_intent.id}"
  end

  def webhook_events
    [
      "payment_intent.succeeded",
      "payment_intent.payment_failed",
      "payment_intent.canceled",
      "invoice.payment_succeeded",
      "invoice.payment_failed",
      "customer.subscription.created",
      "customer.subscription.updated",
      "customer.subscription.deleted",
      "payment_method.attached",
      "setup_intent.succeeded"
    ]
  end

  def handle_payment_succeeded(payment_intent)
    Rails.logger.info "Stripe payment succeeded: #{payment_intent['id']}"

    {
      success: true,
      transaction_id: payment_intent["id"],
      status: "succeeded",
      event_type: "payment_succeeded",
      amount: payment_intent["amount"],
      currency: payment_intent["currency"]
    }
  end

  def handle_payment_failed(payment_intent)
    Rails.logger.warn "Stripe payment failed: #{payment_intent['id']}"

    {
      success: true,
      transaction_id: payment_intent["id"],
      status: "failed",
      event_type: "payment_failed",
      error: payment_intent["last_payment_error"]&.dig("message"),
      amount: payment_intent["amount"],
      currency: payment_intent["currency"]
    }
  end

  def handle_payment_canceled(payment_intent)
    Rails.logger.info "Stripe payment canceled: #{payment_intent['id']}"

    {
      success: true,
      transaction_id: payment_intent["id"],
      status: "canceled",
      event_type: "payment_canceled",
      amount: payment_intent["amount"],
      currency: payment_intent["currency"]
    }
  end

  def handle_invoice_payment_succeeded(invoice)
    {
      success: true,
      transaction_id: invoice["payment_intent"],
      status: "succeeded",
      event_type: "subscription_payment_succeeded",
      subscription_id: invoice["subscription"],
      amount: invoice["amount_paid"],
      currency: invoice["currency"]
    }
  end

  def handle_invoice_payment_failed(invoice)
    {
      success: true,
      transaction_id: invoice["payment_intent"],
      status: "failed",
      event_type: "subscription_payment_failed",
      subscription_id: invoice["subscription"],
      amount: invoice["amount_due"],
      currency: invoice["currency"]
    }
  end

  def handle_subscription_created(subscription)
    {
      success: true,
      subscription_id: subscription["id"],
      status: subscription["status"],
      event_type: "subscription_created",
      customer_id: subscription["customer"]
    }
  end

  def handle_subscription_updated(subscription)
    {
      success: true,
      subscription_id: subscription["id"],
      status: subscription["status"],
      event_type: "subscription_updated",
      customer_id: subscription["customer"]
    }
  end

  def handle_subscription_deleted(subscription)
    {
      success: true,
      subscription_id: subscription["id"],
      status: "canceled",
      event_type: "subscription_canceled",
      customer_id: subscription["customer"]
    }
  end

  def handle_card_error(error)
    {
      success: false,
      error: error.message,
      error_code: error.code,
      error_type: "card_error",
      decline_code: error.decline_code
    }
  end

  def handle_invalid_request_error(error)
    {
      success: false,
      error: error.message,
      error_code: error.code,
      error_type: "invalid_request"
    }
  end

  def handle_authentication_error(error)
    {
      success: false,
      error: "Authentication failed - check API key",
      error_code: error.code,
      error_type: "authentication_error"
    }
  end

  def handle_connection_error(error)
    {
      success: false,
      error: "Network connection failed",
      error_type: "connection_error"
    }
  end

  def handle_generic_stripe_error(error)
    {
      success: false,
      error: error.message,
      error_code: error.code,
      error_type: "stripe_error"
    }
  end

  def handle_unknown_error(error)
    Rails.logger.error "Unknown Stripe error: #{error.message}"
    {
      success: false,
      error: "An unexpected error occurred",
      error_type: "unknown_error"
    }
  end
end
