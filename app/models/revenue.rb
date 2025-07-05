class Revenue < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  
  belongs_to :festival
  belongs_to :budget_category
  belongs_to :user
  has_many_attached :documents

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true, length: { maximum: 500 }
  validates :revenue_date, presence: true
  validates :revenue_type, presence: true
  validates :status, presence: true

  REVENUE_TYPES = %w[ticket_sales sponsorship vendor_fees donation grant merchandise other].freeze
  STATUSES = %w[pending confirmed received].freeze

  validates :revenue_type, inclusion: { in: REVENUE_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(revenue_date: :desc, created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_category, ->(category) { where(budget_category: category) }
  scope :by_type, ->(type) { where(revenue_type: type) }
  scope :by_date_range, ->(start_date, end_date) { where(revenue_date: start_date..end_date) }
  scope :confirmed, -> { where(status: %w[confirmed received]) }
  scope :this_month, -> { where(revenue_date: Date.current.beginning_of_month..Date.current.end_of_month) }

  after_update :notify_revenue_status_change, if: :saved_change_to_status?

  def revenue_type_text
    case revenue_type
    when 'ticket_sales' then 'チケット売上'
    when 'sponsorship' then 'スポンサーシップ'
    when 'vendor_fees' then 'ベンダー出店料'
    when 'donation' then '寄付'
    when 'grant' then '助成金'
    when 'merchandise' then 'グッズ売上'
    when 'other' then 'その他'
    else revenue_type.humanize
    end
  end

  def status_text
    case status
    when 'pending' then '保留中'
    when 'confirmed' then '確定'
    when 'received' then '受領済み'
    else status.humanize
    end
  end

  def status_color
    case status
    when 'pending' then 'warning'
    when 'confirmed' then 'info'
    when 'received' then 'success'
    else 'secondary'
    end
  end

  def can_be_modified_by?(current_user)
    return false unless current_user
    return true if current_user.admin? || current_user.committee_member?
    return true if user == current_user && status == 'pending'
    false
  end

  def can_be_confirmed_by?(current_user)
    return false unless current_user
    return false unless status == 'pending'
    current_user.admin? || current_user.committee_member? || festival.user == current_user
  end

  def can_be_received_by?(current_user)
    return false unless current_user
    current_user.admin? || current_user.committee_member? || festival.user == current_user
  end

  def confirm!(confirmer, notes = nil)
    return false unless can_be_confirmed_by?(confirmer)
    
    transaction do
      update!(status: 'confirmed')
      
      NotificationService.create_notification(
        recipient: user,
        sender: confirmer,
        notifiable: self,
        notification_type: 'revenue_confirmed',
        title: '収入が確定されました',
        message: "#{budget_category.name}: ¥#{number_with_delimiter(amount.to_i)}"
      )
      
      true
    end
  end

  def mark_received!(receiver, notes = nil)
    return false unless can_be_received_by?(receiver)
    return false unless status == 'confirmed'
    
    transaction do
      update!(status: 'received')
      
      NotificationService.create_notification(
        recipient: user,
        sender: receiver,
        notifiable: self,
        notification_type: 'revenue_received',
        title: '収入を受領しました',
        message: "#{budget_category.name}: ¥#{number_with_delimiter(amount.to_i)}"
      )
      
      true
    end
  end

  def amount_formatted
    "¥#{number_with_delimiter(amount.to_i)}"
  end

  def tax_amount(tax_rate = 0.1)
    amount * tax_rate
  end

  def amount_including_tax(tax_rate = 0.1)
    amount * (1 + tax_rate)
  end

  private

  def notify_revenue_status_change
    # Skip if this is an automated system update
    return if festival.user.nil?

    NotificationService.create_notification(
      recipient: user,
      sender: festival.user,
      notifiable: self,
      notification_type: 'revenue_status_changed',
      title: "収入ステータス変更: #{revenue_type_text}",
      message: "ステータス: #{status_text}"
    )
  end
end
