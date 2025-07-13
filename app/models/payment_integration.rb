class PaymentIntegration < ApplicationRecord
  belongs_to :user
  belongs_to :festival, optional: true
  has_many :payment_transactions, dependent: :destroy
  
  validates :provider, presence: true, inclusion: { in: %w[stripe square paypal bank_transfer] }
  validates :name, presence: true
  validates :account_id, presence: true
  
  encrypts :api_key
  encrypts :api_secret
  encrypts :webhook_secret
  
  scope :active, -> { where(active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  
  enum status: {
    connected: 0,
    disconnected: 1,
    error: 2,
    pending_verification: 3,
    suspended: 4
  }
  
  enum transaction_fee_type: {
    percentage: 0,
    fixed: 1,
    percentage_plus_fixed: 2
  }

  before_create :set_defaults
  after_update :update_payment_methods, if: :saved_change_to_active?

  def stripe?
    provider == 'stripe'
  end

  def square?
    provider == 'square'
  end

  def paypal?
    provider == 'paypal'
  end

  def bank_transfer?
    provider == 'bank_transfer'
  end

  def payment_enabled?
    active? && connected? && api_key.present?
  end

  def supports_refunds?
    %w[stripe square paypal].include?(provider)
  end

  def supports_subscriptions?
    %w[stripe square].include?(provider)
  end

  def supports_webhooks?
    %w[stripe square paypal].include?(provider)
  end

  def payment_service
    @payment_service ||= case provider
                        when 'stripe'
                          StripePaymentService.new(self)
                        when 'square'
                          SquarePaymentService.new(self)
                        when 'paypal'
                          PaypalPaymentService.new(self)
                        when 'bank_transfer'
                          BankTransferService.new(self)
                        end
  end

  def process_payment!(amount, options = {})
    return { success: false, error: 'Payment integration not enabled' } unless payment_enabled?

    begin
      result = payment_service.create_payment(amount, options)
      
      # Create transaction record
      transaction = payment_transactions.create!(
        transaction_id: result[:transaction_id],
        amount: amount,
        currency: options[:currency] || 'JPY',
        status: result[:status],
        payment_method: options[:payment_method],
        customer_info: options[:customer_info],
        metadata: options[:metadata] || {}
      )
      
      result.merge(payment_transaction_id: transaction.id)
    rescue => error
      Rails.logger.error "Payment processing failed for integration #{id}: #{error.message}"
      update!(last_error: error.message)
      { success: false, error: error.message }
    end
  end

  def create_refund!(transaction_id, amount = nil, reason = nil)
    return { success: false, error: 'Refunds not supported' } unless supports_refunds?

    transaction = payment_transactions.find_by(transaction_id: transaction_id)
    return { success: false, error: 'Transaction not found' } unless transaction

    begin
      result = payment_service.create_refund(transaction_id, amount, reason)
      
      # Update transaction status
      transaction.update!(
        status: 'refunded',
        refund_amount: amount || transaction.amount,
        refund_reason: reason
      )
      
      result
    rescue => error
      Rails.logger.error "Refund failed for transaction #{transaction_id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def test_connection
    payment_service.test_connection
  rescue => error
    { success: false, message: error.message }
  end

  def calculate_fees(amount)
    return 0 if transaction_fee_rate.zero?

    case transaction_fee_type
    when 'percentage'
      (amount * transaction_fee_rate / 100).round
    when 'fixed'
      transaction_fee_rate
    when 'percentage_plus_fixed'
      ((amount * transaction_fee_rate / 100) + (transaction_fee_fixed || 0)).round
    else
      0
    end
  end

  def net_amount(gross_amount)
    gross_amount - calculate_fees(gross_amount)
  end

  def create_payment_intent(amount, options = {})
    return { success: false, error: 'Payment integration not enabled' } unless payment_enabled?

    payment_service.create_payment_intent(amount, options)
  rescue => error
    Rails.logger.error "Payment intent creation failed: #{error.message}"
    { success: false, error: error.message }
  end

  def get_payment_methods
    return [] unless payment_enabled?

    payment_service.get_payment_methods
  rescue => error
    Rails.logger.error "Failed to fetch payment methods: #{error.message}"
    []
  end

  def analytics_summary(start_date = 30.days.ago, end_date = Time.current)
    transactions = payment_transactions.where(created_at: start_date..end_date)
    
    {
      total_transactions: transactions.count,
      successful_transactions: transactions.where(status: %w[completed succeeded]).count,
      failed_transactions: transactions.where(status: %w[failed canceled]).count,
      total_amount: transactions.where(status: %w[completed succeeded]).sum(:amount),
      total_fees: transactions.where(status: %w[completed succeeded]).sum { |t| calculate_fees(t.amount) },
      average_transaction: transactions.where(status: %w[completed succeeded]).average(:amount)&.round(2) || 0,
      refunded_amount: transactions.where.not(refund_amount: nil).sum(:refund_amount),
      currency_breakdown: transactions.group(:currency).sum(:amount),
      daily_volume: transactions.group_by_day(:created_at, last: 30).sum(:amount)
    }
  end

  def webhook_url
    case provider
    when 'stripe'
      Rails.application.routes.url_helpers.api_v1_webhooks_stripe_url
    when 'square'
      Rails.application.routes.url_helpers.api_v1_webhooks_square_url  
    when 'paypal'
      Rails.application.routes.url_helpers.api_v1_webhooks_paypal_url
    else
      nil
    end
  end

  def setup_webhooks!
    return false unless supports_webhooks?

    begin
      result = payment_service.setup_webhook(webhook_url)
      
      if result[:success]
        update!(
          webhook_id: result[:webhook_id],
          webhook_secret: result[:webhook_secret]
        )
        true
      else
        update!(last_error: result[:error])
        false
      end
    rescue => error
      update!(last_error: error.message)
      false
    end
  end

  def process_webhook(payload, signature = nil)
    return { success: false, error: 'Webhooks not supported' } unless supports_webhooks?

    begin
      # Verify webhook signature
      if webhook_secret.present? && signature.present?
        unless payment_service.verify_webhook_signature(payload, signature, webhook_secret)
          return { success: false, error: 'Invalid webhook signature' }
        end
      end

      # Process webhook event
      result = payment_service.process_webhook(payload)
      
      # Update transaction status if applicable
      if result[:transaction_id].present?
        transaction = payment_transactions.find_by(transaction_id: result[:transaction_id])
        if transaction && result[:status].present?
          transaction.update!(status: result[:status])
          
          # Trigger notifications for status changes
          case result[:status]
          when 'completed', 'succeeded'
            notify_payment_success(transaction)
          when 'failed', 'canceled'
            notify_payment_failure(transaction)
          end
        end
      end
      
      result
    rescue => error
      Rails.logger.error "Webhook processing failed: #{error.message}"
      { success: false, error: error.message }
    end
  end

  private

  def set_defaults
    self.active ||= true
    self.status ||= :connected
    self.transaction_fee_type ||= :percentage
    self.transaction_fee_rate ||= 0.0
    self.currency ||= 'JPY'
  end

  def update_payment_methods
    return unless active?
    
    PaymentMethodUpdateJob.perform_later(id)
  end

  def notify_payment_success(transaction)
    # Send notification to user about successful payment
    NotificationService.create_notification(
      user: user,
      type: 'payment_confirmed',
      title: 'Payment Confirmed',
      message: "Payment of ¥#{transaction.amount.to_i.to_s(:delimited)} has been confirmed",
      related_object: transaction
    )

    # Trigger webhook delivery
    WebhookDeliveryService.payment_confirmed({
      id: transaction.id,
      amount: transaction.amount,
      currency: transaction.currency,
      payment_method: transaction.payment_method,
      festival_name: festival&.name
    })
  end

  def notify_payment_failure(transaction)
    # Send notification about failed payment
    NotificationService.create_notification(
      user: user,
      type: 'payment_failed',
      title: 'Payment Failed',
      message: "Payment of ¥#{transaction.amount.to_i.to_s(:delimited)} has failed",
      related_object: transaction
    )

    # Trigger webhook delivery
    WebhookDeliveryService.deliver('payment_failed', {
      id: transaction.id,
      amount: transaction.amount,
      currency: transaction.currency,
      payment_method: transaction.payment_method,
      festival_name: festival&.name,
      error: transaction.error_message
    })
  end
end