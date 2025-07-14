class Api::V1::Webhooks::PaypalController < Api::V1::BaseController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  before_action :verify_paypal_signature
  before_action :find_payment_integration

  def handle
    begin
      # Process the webhook event
      result = @integration.process_webhook(request.body.read)

      if result[:success]
        # Log successful webhook processing
        Rails.logger.info "PayPal webhook processed successfully: #{@event_type}"

        # Update transaction status if applicable
        if result[:transaction_id].present?
          update_transaction_status(result)
        end

        # Trigger any additional business logic
        handle_business_logic(result)

        render json: { received: true }, status: :ok
      else
        Rails.logger.error "PayPal webhook processing failed: #{result[:error]}"
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in PayPal webhook: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    rescue => e
      Rails.logger.error "PayPal webhook error: #{e.message}"
      render json: { error: "Internal server error" }, status: :internal_server_error
    end
  end

  private

  def verify_paypal_signature
    payload = request.body.read

    begin
      # Parse the event to find the integration
      event = JSON.parse(payload)

      # PayPal webhook verification is different from Stripe/Square
      # It uses certificate verification rather than HMAC signatures
      # For now, we'll implement basic verification

      # Find the integration by webhook or merchant details
      integration = find_paypal_integration_from_event(event)

      unless integration
        Rails.logger.warn "No PayPal integration found for webhook"
        return render json: { error: "Integration not found" }, status: :not_found
      end

      # Basic event validation - check required fields
      unless validate_paypal_event(event)
        Rails.logger.warn "Invalid PayPal webhook event structure"
        return render json: { error: "Invalid event structure" }, status: :bad_request
      end

      @integration = integration
      @event_data = event
      @event_type = event["event_type"]

    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in PayPal webhook: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    rescue => e
      Rails.logger.error "PayPal webhook verification error: #{e.message}"
      render json: { error: "Verification failed" }, status: :internal_server_error
    end
  end

  def find_payment_integration
    # Integration should already be set in verify_paypal_signature
    unless @integration
      Rails.logger.error "Payment integration not found for PayPal webhook"
      render json: { error: "Integration not found" }, status: :not_found
    end
  end

  def find_paypal_integration_from_event(event)
    # Try to find integration by custom data in the event
    if event["resource"] && event["resource"]["custom"]
      begin
        custom_data = JSON.parse(event["resource"]["custom"])
        integration_id = custom_data["integration_id"]
        if integration_id
          integration = PaymentIntegration.find_by(id: integration_id, provider: "paypal")
          return integration if integration
        end
      rescue JSON::ParserError
        # Custom data is not JSON, continue with other methods
      end
    end

    # Try to find by merchant_id if available
    if event["resource"] && event["resource"]["merchant_id"]
      integration = PaymentIntegration.find_by(account_id: event["resource"]["merchant_id"], provider: "paypal")
      return integration if integration
    end

    # Fallback: find any active PayPal integration (not recommended for production)
    PaymentIntegration.where(provider: "paypal", active: true).first
  end

  def validate_paypal_event(event)
    # Basic validation of PayPal webhook event structure
    required_fields = [ "id", "create_time", "resource_type", "event_type", "resource" ]
    required_fields.all? { |field| event[field].present? }
  end

  def update_transaction_status(result)
    return unless result[:transaction_id]

    # For PayPal, transaction_id might be the parent payment ID
    # Look for transaction by transaction_id or sale_id
    transaction = @integration.payment_transactions.find_by(
      transaction_id: result[:transaction_id]
    )

    # If not found by transaction_id, try to find by sale_id in metadata
    unless transaction
      transaction = @integration.payment_transactions.find do |t|
        t.metadata["sale_id"] == result[:sale_id] if result[:sale_id]
      end
    end

    if transaction && result[:status]
      # Map PayPal statuses to our internal statuses
      internal_status = map_paypal_status(result[:status])

      transaction.update!(
        status: internal_status,
        metadata: transaction.metadata.merge(
          webhook_processed_at: Time.current.iso8601,
          webhook_event_type: @event_type,
          paypal_sale_id: result[:sale_id]
        ).compact
      )

      Rails.logger.info "Updated transaction #{transaction.id} status to #{internal_status}"
    end
  end

  def map_paypal_status(paypal_status)
    case paypal_status.downcase
    when "completed"
      "completed"
    when "denied", "failed"
      "failed"
    when "pending"
      "pending"
    when "canceled", "cancelled"
      "canceled"
    when "refunded"
      "refunded"
    else
      paypal_status.downcase
    end
  end

  def handle_business_logic(result)
    case @event_type
    when "PAYMENT.SALE.COMPLETED"
      handle_payment_success(result)
    when "PAYMENT.SALE.DENIED"
      handle_payment_failure(result)
    when "PAYMENT.SALE.REFUNDED"
      handle_payment_refunded(result)
    when "BILLING.SUBSCRIPTION.ACTIVATED"
      handle_subscription_activated(result)
    when "BILLING.SUBSCRIPTION.CANCELLED"
      handle_subscription_cancelled(result)
    when "BILLING.SUBSCRIPTION.SUSPENDED"
      handle_subscription_suspended(result)
    when "BILLING.SUBSCRIPTION.PAYMENT.FAILED"
      handle_subscription_payment_failed(result)
    when "BILLING.SUBSCRIPTION.PAYMENT.COMPLETED"
      handle_subscription_payment_success(result)
    else
      Rails.logger.debug "No specific business logic for PayPal event: #{@event_type}"
    end
  end

  def handle_payment_success(result)
    # Send success notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: "payment_confirmed",
        title: "Payment Confirmed",
        message: "PayPal payment of ¥#{result[:amount]} has been confirmed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery to external systems
    WebhookDeliveryService.deliver("paypal_payment_succeeded", {
      integration_id: @integration.id,
      transaction_id: result[:transaction_id],
      sale_id: result[:sale_id],
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
        type: "payment_failed",
        title: "Payment Failed",
        message: "PayPal payment of ¥#{result[:amount]} failed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_payment_failed", {
      integration_id: @integration.id,
      transaction_id: result[:transaction_id],
      sale_id: result[:sale_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })

    # Log for admin review
    Rails.logger.warn "PayPal payment failed for integration #{@integration.id}"
  end

  def handle_payment_refunded(result)
    # Send refund notification
    if @integration.festival
      NotificationService.create_notification(
        user: @integration.user,
        type: "refund_processed",
        title: "Refund Processed",
        message: "PayPal refund of ¥#{result[:amount]} has been processed for #{@integration.festival.name}",
        related_object: @integration.festival
      )
    end

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_payment_refunded", {
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

  def handle_subscription_activated(result)
    # Send subscription activation notification
    NotificationService.create_notification(
      user: @integration.user,
      type: "subscription_activated",
      title: "PayPal Subscription Activated",
      message: "Your PayPal subscription has been activated",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_subscription_activated", {
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
      type: "subscription_cancelled",
      title: "PayPal Subscription Cancelled",
      message: "Your PayPal subscription has been cancelled",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_subscription_cancelled", {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_suspended(result)
    # Send subscription suspension notification
    NotificationService.create_notification(
      user: @integration.user,
      type: "subscription_suspended",
      title: "PayPal Subscription Suspended",
      message: "Your PayPal subscription has been suspended. Please check your payment method.",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_subscription_suspended", {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_payment_failed(result)
    # Send subscription payment failure notification
    NotificationService.create_notification(
      user: @integration.user,
      type: "subscription_payment_failed",
      title: "PayPal Subscription Payment Failed",
      message: "PayPal subscription payment of ¥#{result[:amount]} has failed. Please update your payment method.",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_subscription_payment_failed", {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })
  end

  def handle_subscription_payment_success(result)
    # Send subscription payment success notification
    NotificationService.create_notification(
      user: @integration.user,
      type: "subscription_payment_confirmed",
      title: "PayPal Subscription Payment Confirmed",
      message: "PayPal subscription payment of ¥#{result[:amount]} has been processed",
      related_object: @integration.festival
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver("paypal_subscription_payment_succeeded", {
      integration_id: @integration.id,
      subscription_id: result[:subscription_id],
      amount: result[:amount],
      currency: result[:currency],
      festival_id: @integration.festival_id,
      user_id: @integration.user_id
    })

    # Update festival budget if applicable for subscription payments
    if @integration.festival && result[:amount]
      @integration.festival.increment!(:current_budget, result[:amount])
    end
  end
end
