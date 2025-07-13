class Api::V1::Webhooks::SquareController < Api::V1::BaseController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  
  before_action :verify_square_signature
  before_action :find_payment_integration

  def handle
    begin
      # Process the webhook event
      result = @integration.process_webhook(request.body.read, request.headers['X-Square-Signature'])
      
      if result[:success]
        # Log successful webhook processing
        Rails.logger.info "Square webhook processed successfully: #{@event_type}"
        
        # Update transaction status if applicable
        if result[:transaction_id].present?
          update_transaction_status(result)
        end

        # Trigger any additional business logic
        handle_business_logic(result)
        
        render json: { received: true }, status: :ok
      else
        Rails.logger.error "Square webhook processing failed: #{result[:error]}"
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in Square webhook: #{e.message}"
      render json: { error: 'Invalid JSON' }, status: :bad_request
    rescue => e
      Rails.logger.error "Square webhook error: #{e.message}"
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def verify_square_signature
    payload = request.body.read
    signature = request.headers['X-Square-Signature']
    
    unless signature
      Rails.logger.warn "Missing Square signature header"
      return render json: { error: 'Missing signature' }, status: :bad_request
    end

    begin
      # Parse the event to find the integration
      event = JSON.parse(payload)
      
      # Find the integration by webhook or merchant details
      integration = find_square_integration_from_event(event)
      
      unless integration
        Rails.logger.warn "No Square integration found for webhook"
        return render json: { error: 'Integration not found' }, status: :not_found
      end

      # Verify the signature using the integration's webhook secret
      unless integration.webhook_secret.present?
        Rails.logger.warn "No webhook secret configured for Square integration #{integration.id}"
        return render json: { error: 'Webhook not configured' }, status: :bad_request
      end

      # Verify signature using Square's webhook signature verification
      webhook_url = integration.webhook_url
      expected_signature = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha256'),
        integration.webhook_secret,
        "#{webhook_url}#{payload}"
      )

      unless signature == expected_signature
        Rails.logger.warn "Invalid Square webhook signature"
        return render json: { error: 'Invalid signature' }, status: :unauthorized
      end

      @integration = integration
      @event_data = event
      @event_type = event['type']
      
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in Square webhook: #{e.message}"
      render json: { error: 'Invalid JSON' }, status: :bad_request
    rescue => e
      Rails.logger.error "Square webhook verification error: #{e.message}"
      render json: { error: 'Verification failed' }, status: :internal_server_error
    end
  end

  def find_payment_integration
    # Integration should already be set in verify_square_signature
    unless @integration
      Rails.logger.error "Payment integration not found for Square webhook"
      render json: { error: 'Integration not found' }, status: :not_found
    end
  end

  def find_square_integration_from_event(event)
    # Try to find integration by location_id in the event
    if event['data'] && event['data']['object'] && event['data']['object']['location_id']
      location_id = event['data']['object']['location_id']
      integration = PaymentIntegration.find_by(location_id: location_id, provider: 'square')
      return integration if integration
    end

    # Try to find by merchant_id if available
    if event['merchant_id']
      integration = PaymentIntegration.find_by(account_id: event['merchant_id'], provider: 'square')
      return integration if integration
    end

    # Fallback: find any active Square integration (not recommended for production)
    PaymentIntegration.where(provider: 'square', active: true).first
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
    when 'payment.updated'
      handle_payment_updated(result)
    when 'refund.updated'
      handle_refund_updated(result)
    when 'subscription.updated'
      handle_subscription_updated(result)
    when 'invoice.updated'
      handle_invoice_updated(result)
    when 'customer.updated'
      handle_customer_updated(result)
    else
      Rails.logger.debug "No specific business logic for Square event: #{@event_type}"
    end
  end

  def handle_payment_updated(result)
    case result[:status]
    when 'completed', 'approved'
      handle_payment_success(result)
    when 'failed', 'canceled'
      handle_payment_failure(result)
    when 'pending'
      handle_payment_pending(result)
    else
      Rails.logger.debug "Unhandled Square payment status: #{result[:status]}"
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
    WebhookDeliveryService.deliver('square_payment_succeeded', {
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
    WebhookDeliveryService.deliver('square_payment_failed', {
      integration_id: @integration.id,
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })

    # Log for admin review
    Rails.logger.warn "Square payment failed for integration #{@integration.id}"
  end

  def handle_payment_pending(result)
    # Send pending notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: 'payment_pending',
        title: 'Payment Pending',
        message: "Payment of ¥#{result[:amount]} is being processed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('square_payment_pending', {
      integration_id: @integration.id,
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_refund_updated(result)
    case result[:status]
    when 'completed', 'approved'
      handle_refund_success(result)
    when 'failed', 'rejected'
      handle_refund_failure(result)
    when 'pending'
      handle_refund_pending(result)
    else
      Rails.logger.debug "Unhandled Square refund status: #{result[:status]}"
    end
  end

  def handle_refund_success(result)
    # Send refund success notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: 'refund_processed',
        title: 'Refund Processed',
        message: "Refund of ¥#{result[:amount]} has been processed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('square_refund_succeeded', {
      integration_id: @integration.id,
      refund_id: result[:refund_id],
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })

    # Update festival budget if applicable
    if @integration.festival && result[:amount]
      @integration.festival.decrement!(:current_budget, result[:amount])
    end
  end

  def handle_refund_failure(result)
    # Send refund failure notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: 'refund_failed',
        title: 'Refund Failed',
        message: "Refund of ¥#{result[:amount]} failed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('square_refund_failed', {
      integration_id: @integration.id,
      refund_id: result[:refund_id],
      transaction_id: result[:transaction_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_refund_pending(result)
    # Send refund pending notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: 'refund_pending',
        title: 'Refund Processing',
        message: "Refund of ¥#{result[:amount]} is being processed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end
  end

  def handle_subscription_updated(result)
    case result[:status]
    when 'active'
      handle_subscription_activated(result)
    when 'canceled', 'cancelled'
      handle_subscription_cancelled(result)
    when 'paused'
      handle_subscription_paused(result)
    else
      Rails.logger.debug "Unhandled Square subscription status: #{result[:status]}"
    end
  end

  def handle_subscription_activated(result)
    # Send subscription activation notification
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_activated',
      title: 'Subscription Activated',
      message: 'Your subscription has been activated',
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('square_subscription_activated', {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_cancelled(result)
    # Send subscription cancellation notification
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_cancelled',
      title: 'Subscription Cancelled',
      message: 'Your subscription has been cancelled',
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('square_subscription_cancelled', {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_paused(result)
    # Send subscription pause notification
    NotificationService.create_notification(
      user: @integration.user,
      type: 'subscription_paused',
      title: 'Subscription Paused',
      message: 'Your subscription has been paused',
      related_object: @integration.festival
    )
  end

  def handle_invoice_updated(result)
    Rails.logger.info "Square invoice updated for integration #{@integration.id}: #{result[:invoice_id]}"
    
    # Trigger webhook delivery for invoice updates
    WebhookDeliveryService.deliver('square_invoice_updated', {
      integration_id: @integration.id,
      invoice_id: result[:invoice_id],
      subscription_id: result[:subscription_id],
      status: result[:status],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_customer_updated(result)
    Rails.logger.info "Square customer updated for integration #{@integration.id}: #{result[:customer_id]}"
    
    # Update any cached customer information if needed
    # This is mainly for logging and potential future use
  end
end