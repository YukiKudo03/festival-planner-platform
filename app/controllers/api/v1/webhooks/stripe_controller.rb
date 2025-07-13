class Api::V1::Webhooks::StripeController < Api::V1::BaseController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  
  before_action :verify_stripe_signature
  before_action :find_payment_integration

  def handle
    begin
      # Process the webhook event
      result = @integration.process_webhook(request.body.read, request.headers['Stripe-Signature'])
      
      if result[:success]
        # Log successful webhook processing
        Rails.logger.info "Stripe webhook processed successfully: #{@event_type}"
        
        # Update transaction status if applicable
        if result[:transaction_id].present?
          update_transaction_status(result)
        end

        # Trigger any additional business logic
        handle_business_logic(result)
        
        render json: { received: true }, status: :ok
      else
        Rails.logger.error "Stripe webhook processing failed: #{result[:error]}"
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in Stripe webhook: #{e.message}"
      render json: { error: 'Invalid JSON' }, status: :bad_request
    rescue => e
      Rails.logger.error "Stripe webhook error: #{e.message}"
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def verify_stripe_signature
    payload = request.body.read
    sig_header = request.headers['Stripe-Signature']
    
    unless sig_header
      Rails.logger.warn "Missing Stripe signature header"
      return render json: { error: 'Missing signature' }, status: :bad_request
    end

    begin
      # Find the integration to get the webhook secret
      # We'll need to identify the integration from the webhook payload
      event = JSON.parse(payload)
      
      # Look for integration by webhook or account details
      integration = find_stripe_integration_from_event(event)
      
      unless integration
        Rails.logger.warn "No Stripe integration found for webhook"
        return render json: { error: 'Integration not found' }, status: :not_found
      end

      # Verify the signature using the integration's webhook secret
      unless integration.webhook_secret.present?
        Rails.logger.warn "No webhook secret configured for Stripe integration #{integration.id}"
        return render json: { error: 'Webhook not configured' }, status: :bad_request
      end

      # Verify signature
      unless integration.payment_service.verify_webhook_signature(payload, sig_header, integration.webhook_secret)
        Rails.logger.warn "Invalid Stripe webhook signature"
        return render json: { error: 'Invalid signature' }, status: :unauthorized
      end

      @integration = integration
      @event_data = event
      @event_type = event['type']
      
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in Stripe webhook: #{e.message}"
      render json: { error: 'Invalid JSON' }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.warn "Stripe signature verification failed: #{e.message}"
      render json: { error: 'Invalid signature' }, status: :unauthorized
    rescue => e
      Rails.logger.error "Stripe webhook verification error: #{e.message}"
      render json: { error: 'Verification failed' }, status: :internal_server_error
    end
  end

  def find_payment_integration
    # Integration should already be set in verify_stripe_signature
    unless @integration
      Rails.logger.error "Payment integration not found for Stripe webhook"
      render json: { error: 'Integration not found' }, status: :not_found
    end
  end

  def find_stripe_integration_from_event(event)
    # Try to find integration by metadata in the event
    if event['data'] && event['data']['object'] && event['data']['object']['metadata']
      integration_id = event['data']['object']['metadata']['integration_id']
      if integration_id
        integration = PaymentIntegration.find_by(id: integration_id, provider: 'stripe')
        return integration if integration
      end
    end

    # Try to find by account (if available in event)
    if event['account']
      integration = PaymentIntegration.find_by(account_id: event['account'], provider: 'stripe')
      return integration if integration
    end

    # Fallback: find any active Stripe integration (not recommended for production)
    # In production, you should have a more robust way to identify the correct integration
    PaymentIntegration.where(provider: 'stripe', active: true).first
  end

  def update_transaction_status(result)
    return unless result[:transaction_id]

    transaction = @integration.payment_transactions.find_by(
      transaction_id: result[:transaction_id]
    )

    if transaction && result[:status]
      transaction.update!(
        status: result[:status],
        metadata: transaction.metadata.merge(
          webhook_processed_at: Time.current.iso8601,
          webhook_event_type: @event_type
        )
      )
      
      Rails.logger.info "Updated transaction #{transaction.id} status to #{result[:status]}"
    end
  end

  def handle_business_logic(result)
    case @event_type
    when 'payment_intent.succeeded'
      handle_payment_success(result)
    when 'payment_intent.payment_failed'
      handle_payment_failure(result)
    when 'invoice.payment_succeeded'
      handle_subscription_payment_success(result)
    when 'invoice.payment_failed'
      handle_subscription_payment_failure(result)
    when 'customer.subscription.deleted'
      handle_subscription_cancellation(result)
    when 'customer.subscription.created'
      handle_subscription_creation(result)
    when 'payment_method.attached'
      handle_payment_method_attached(result)
    when 'setup_intent.succeeded'
      handle_setup_intent_success(result)
    else
      Rails.logger.debug "No specific business logic for Stripe event: #{@event_type}"
    end
  end

  def handle_payment_success(result)
    # Send success notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: 'payment_confirmed',
        title: 'Payment Confirmed',
        message: "Payment of ¥#{result[:amount]} has been confirmed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery to external systems
    WebhookDeliveryService.deliver('stripe_payment_succeeded', {
      integration_id: @integration.id,
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })

    # Update festival budget if applicable
    if @integration.festival && result[:amount]
      @integration.festival.increment!(:current_budget, result[:amount])
    end
  end

  def handle_payment_failure(result)
    # Send failure notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: 'payment_failed',
        title: 'Payment Failed',
        message: "Payment of ¥#{result[:amount]} failed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('stripe_payment_failed', {
      integration_id: @integration.id,
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      error: result[:error],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })

    # Log for admin review
    Rails.logger.warn "Stripe payment failed for integration #{@integration.id}: #{result[:error]}"
  end

  def handle_subscription_payment_success(result)
    # Handle recurring payment success
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_payment_confirmed',
      title: 'Subscription Payment Confirmed',
      message: "Subscription payment of ¥#{result[:amount]} has been processed",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('stripe_subscription_payment_succeeded', {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_payment_failure(result)
    # Handle recurring payment failure
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_payment_failed',
      title: 'Subscription Payment Failed',
      message: "Subscription payment of ¥#{result[:amount]} has failed. Please update your payment method.",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('stripe_subscription_payment_failed', {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_cancellation(result)
    # Handle subscription cancellation
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_cancelled',
      title: 'Subscription Cancelled',
      message: 'Your subscription has been cancelled',
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('stripe_subscription_cancelled', {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      customer_id: result[:customer_id],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_creation(result)
    # Handle new subscription creation
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_created',
      title: 'Subscription Created',
      message: 'Your subscription has been successfully created',
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('stripe_subscription_created', {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      customer_id: result[:customer_id],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_payment_method_attached(result)
    # Log payment method attachment
    Rails.logger.info "Payment method attached for Stripe integration #{@integration.id}"
    
    # Optionally notify user
    NotificationService.create_notification(
      user: @integration.user,
      type: 'payment_method_added',
      title: 'Payment Method Added',
      message: 'A new payment method has been added to your account',
      related_object: @integration.festival
    )
  end

  def handle_setup_intent_success(result)
    # Handle successful setup intent (usually for saving payment methods)
    Rails.logger.info "Setup intent succeeded for Stripe integration #{@integration.id}"
    
    # Optionally notify user
    NotificationService.create_notification(
      user: @integration.user,
      type: 'payment_setup_complete',
      title: 'Payment Setup Complete',
      message: 'Your payment method has been successfully set up',
      related_object: @integration.festival
    )
  end
end