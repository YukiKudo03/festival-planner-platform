class Expense < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  
  belongs_to :festival
  belongs_to :budget_category
  belongs_to :user
  has_many_attached :receipts

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true, length: { maximum: 500 }
  validates :expense_date, presence: true
  validates :payment_method, presence: true
  validates :status, presence: true

  PAYMENT_METHODS = %w[cash credit_card bank_transfer check digital_payment other].freeze
  STATUSES = %w[draft pending approved rejected reimbursed].freeze

  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(expense_date: :desc, created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_category, ->(category) { where(budget_category: category) }
  scope :by_date_range, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
  scope :pending_approval, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :this_month, -> { where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month) }

  after_create :check_budget_limits
  after_update :check_budget_limits, if: :saved_change_to_amount?

  def payment_method_text
    case payment_method
    when 'cash' then '現金'
    when 'credit_card' then 'クレジットカード'
    when 'bank_transfer' then '銀行振込'
    when 'check' then '小切手'
    when 'digital_payment' then 'デジタル決済'
    when 'other' then 'その他'
    else payment_method.humanize
    end
  end

  def status_text
    case status
    when 'draft' then '下書き'
    when 'pending' then '承認待ち'
    when 'approved' then '承認済み'
    when 'rejected' then '却下'
    when 'reimbursed' then '払い戻し済み'
    else status.humanize
    end
  end

  def status_color
    case status
    when 'draft' then 'secondary'
    when 'pending' then 'warning'
    when 'approved' then 'success'
    when 'rejected' then 'danger'
    when 'reimbursed' then 'info'
    else 'secondary'
    end
  end

  def can_be_modified_by?(current_user)
    return false unless current_user
    return true if current_user.admin? || current_user.committee_member?
    return true if user == current_user && %w[draft pending].include?(status)
    false
  end

  def can_be_approved_by?(current_user)
    return false unless current_user
    return false unless status == 'pending'
    current_user.admin? || current_user.committee_member? || festival.user == current_user
  end

  def approve!(approver, notes = nil)
    return false unless can_be_approved_by?(approver)
    
    transaction do
      update!(status: 'approved')
      
      # 通知を送信
      NotificationService.create_notification(
        recipient: user,
        sender: approver,
        notifiable: self,
        notification_type: 'expense_approved',
        title: '支出が承認されました',
        message: "#{budget_category.name}: ¥#{amount.to_i.to_s(:delimited)}"
      )
    end
  end

  def reject!(approver, reason)
    return false unless can_be_approved_by?(approver)
    return false if reason.blank?
    
    transaction do
      update!(status: 'rejected')
      
      # 通知を送信
      NotificationService.create_notification(
        recipient: user,
        sender: approver,
        notifiable: self,
        notification_type: 'expense_rejected',
        title: '支出が却下されました',
        message: "理由: #{reason}"
      )
    end
  end

  def amount_formatted
    "¥#{amount.to_i.to_s(:delimited)}"
  end

  def tax_amount(tax_rate = 0.1)
    amount * tax_rate
  end

  def amount_including_tax(tax_rate = 0.1)
    amount * (1 + tax_rate)
  end

  private

  def check_budget_limits
    return unless status == 'approved'
    
    category = budget_category
    
    # 予算超過チェック
    if category.over_budget?
      # 予算超過の通知
      festival.user&.then do |festival_manager|
        NotificationService.create_notification(
          recipient: festival_manager,
          sender: user,
          notifiable: category,
          notification_type: 'budget_exceeded',
          title: "予算超過: #{category.name}",
          message: "予算額: #{number_with_delimiter(category.budget_limit.to_i)}円、使用額: #{number_with_delimiter(category.total_budget_used.to_i)}円"
        )
      end
    elsif category.near_budget_limit?
      # 予算上限近づきの警告
      festival.user&.then do |festival_manager|
        NotificationService.create_notification(
          recipient: festival_manager,
          sender: user,
          notifiable: category,
          notification_type: 'budget_warning',
          title: "予算残り僅か: #{category.name}",
          message: "使用率: #{category.budget_usage_percentage}%"
        )
      end
    end
  end
end
