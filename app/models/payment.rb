class Payment < ApplicationRecord
  belongs_to :festival
  belongs_to :user

  # Enums
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled",
    refunded: "refunded"
  }

  enum :payment_method, {
    stripe: "stripe",
    paypal: "paypal",
    bank_transfer: "bank_transfer",
    cash: "cash"
  }

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
  validates :status, presence: true
  validates :currency, presence: true, inclusion: { in: %w[JPY USD EUR] }
  validates :customer_email, presence: true
  validates :customer_name, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :external_transaction_id, uniqueness: true, allow_blank: true

  # Custom validations
  validate :validate_payment_method_requirements
  validate :validate_amount_limits
  validate :validate_status_transitions

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_festival, ->(festival) { where(festival: festival) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :successful, -> { where(status: [ :completed, :refunded ]) }
  scope :failed_or_cancelled, -> { where(status: [ :failed, :cancelled ]) }

  # Callbacks
  before_validation :set_defaults
  before_save :calculate_processing_fee
  after_update :notify_status_change, if: :saved_change_to_status?

  # Instance methods
  def accessible_by?(user)
    return true if user.admin? || user.system_admin?
    return true if self.user == user
    return true if festival.accessible_by?(user)
    false
  end

  def can_be_modified_by?(user)
    return false unless accessible_by?(user)
    return true if user.admin? || user.system_admin?
    return true if self.user == user && pending?
    false
  end

  def can_be_cancelled_by?(user)
    return false unless accessible_by?(user)
    return false unless cancellable?
    return true if user.admin? || user.system_admin?
    return true if self.user == user
    false
  end

  def confirmable_by?(user)
    return false unless accessible_by?(user)
    return false unless confirmable?
    return true if user.admin? || user.system_admin?
    return true if festival.can_be_modified_by?(user)
    false
  end

  def cancellable?
    pending? || processing?
  end

  def can_be_cancelled?
    cancellable?
  end

  def confirmable?
    processing?
  end

  def refundable?
    completed? && confirmed_at.present? && confirmed_at > 30.days.ago
  end

  def status_color
    case status
    when "pending"
      "warning"
    when "processing"
      "info"
    when "completed"
      "success"
    when "failed"
      "danger"
    when "cancelled"
      "secondary"
    when "refunded"
      "dark"
    else
      "light"
    end
  end

  def net_amount
    amount - processing_fee
  end

  def formatted_amount
    "#{currency} #{amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def processing_time
    return nil unless processed_at
    processed_at - created_at
  end

  def confirmation_time
    return nil unless confirmed_at || processed_at
    (confirmed_at || Time.current) - (processed_at || created_at)
  end

  def total_processing_time
    return nil unless confirmed_at
    confirmed_at - created_at
  end

  def payment_instructions
    case payment_method
    when "bank_transfer"
      metadata["instructions"] || {}
    when "cash"
      metadata["instructions"] || {}
    else
      {}
    end
  end

  def external_payment_url
    case payment_method
    when "stripe"
      metadata["checkout_url"]
    when "paypal"
      metadata["redirect_url"]
    else
      nil
    end
  end

  def receipt_data
    {
      payment_id: id,
      festival_name: festival.name,
      amount: formatted_amount,
      payment_method: payment_method.humanize,
      status: status.humanize,
      transaction_id: external_transaction_id,
      processed_at: processed_at,
      confirmed_at: confirmed_at,
      customer_name: customer_name,
      customer_email: customer_email,
      description: description
    }
  end

  # Class methods
  def self.total_revenue(festival = nil)
    scope = festival ? by_festival(festival) : all
    scope.completed.sum(:amount)
  end

  def self.total_fees(festival = nil)
    scope = festival ? by_festival(festival) : all
    scope.completed.sum(:processing_fee)
  end

  def self.revenue_by_method
    completed.group(:payment_method).sum(:amount)
  end

  def self.daily_revenue(days = 30)
    completed.where(confirmed_at: days.days.ago..Time.current)
             .group_by_day(:confirmed_at)
             .sum(:amount)
  end

  def self.average_processing_time
    completed.where.not(processed_at: nil, confirmed_at: nil)
             .average("EXTRACT(epoch FROM (confirmed_at - processed_at)) / 60") # minutes
  end

  def self.conversion_rate
    total_payments = count
    return 0 if total_payments.zero?

    successful_payments = successful.count
    (successful_payments.to_f / total_payments * 100).round(2)
  end

  private

  def set_defaults
    self.currency ||= "JPY"
    self.customer_email ||= user&.email
    self.customer_name ||= user&.full_name
    self.metadata ||= {}
  end

  def calculate_processing_fee
    return unless amount_changed? || payment_method_changed?

    self.processing_fee = PaymentService.calculate_fees(amount, payment_method)
  end

  def validate_payment_method_requirements
    return unless payment_method.present?

    method_info = PaymentService.available_methods.find { |m| m[:id] == payment_method }
    return unless method_info

    # Check amount limits
    if amount.present?
      if amount < method_info[:min_amount]
        errors.add(:amount, "は#{payment_method.humanize}の最小額#{method_info[:min_amount]}円以上である必要があります")
      end

      if amount > method_info[:max_amount]
        errors.add(:amount, "は#{payment_method.humanize}の最大額#{method_info[:max_amount]}円以下である必要があります")
      end
    end

    # Check currency support
    if currency.present? && !method_info[:supported_currencies].include?(currency)
      errors.add(:currency, "は#{payment_method.humanize}でサポートされていません")
    end

    # Method-specific requirements
    case payment_method
    when "stripe"
      if customer_email.blank?
        errors.add(:customer_email, "はStripe決済で必須です")
      end
    when "bank_transfer"
      if customer_name.blank?
        errors.add(:customer_name, "は銀行振込で必須です")
      end
    end
  end

  def validate_amount_limits
    return unless amount.present?

    # Global limits
    if amount > 10_000_000
      errors.add(:amount, "は1000万円以下である必要があります")
    end

    if amount < 1
      errors.add(:amount, "は1円以上である必要があります")
    end
  end

  def validate_status_transitions
    return unless status_changed? && persisted?

    valid_transitions = {
      "pending" => %w[processing failed cancelled],
      "processing" => %w[completed failed cancelled],
      "completed" => %w[refunded],
      "failed" => %w[pending],
      "cancelled" => [],
      "refunded" => []
    }

    old_status = status_was
    new_status = status

    unless valid_transitions[old_status]&.include?(new_status)
      errors.add(:status, "を#{old_status}から#{new_status}に変更することはできません")
    end
  end

  def notify_status_change
    case status
    when "completed"
      PaymentNotificationService.payment_completed(self)
    when "failed"
      PaymentNotificationService.payment_failed(self)
    when "cancelled"
      PaymentNotificationService.payment_cancelled(self)
    when "refunded"
      PaymentNotificationService.payment_refunded(self)
    end
  end
end
