class BudgetApproval < ApplicationRecord
  include ActionView::Helpers::NumberHelper

  belongs_to :festival
  belongs_to :budget_category
  belongs_to :approver, polymorphic: true

  validates :requested_amount, presence: true, numericality: { greater_than: 0 }
  validates :approved_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  STATUSES = %w[pending approved rejected].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_approver, ->(approver) { where(approver: approver) }
  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }

  after_create :notify_approval_request
  after_update :notify_approval_decision, if: :saved_change_to_status?

  def status_text
    case status
    when "pending" then "承認待ち"
    when "approved" then "承認済み"
    when "rejected" then "却下"
    else status.humanize
    end
  end

  def status_color
    case status
    when "pending" then "warning"
    when "approved" then "success"
    when "rejected" then "danger"
    else "secondary"
    end
  end

  def requested_amount_formatted
    "¥#{number_with_delimiter(requested_amount.to_i)}"
  end

  def approved_amount_formatted
    "¥#{number_with_delimiter(approved_amount.to_i)}"
  end

  def difference_amount
    approved_amount - requested_amount
  end

  def difference_amount_formatted
    amount = difference_amount
    if amount >= 0
      "+¥#{number_with_delimiter(amount.to_i)}"
    else
      "-¥#{number_with_delimiter(amount.abs.to_i)}"
    end
  end

  def approval_percentage
    return 0 if requested_amount.zero?
    (approved_amount / requested_amount * 100).round(2)
  end

  def can_be_modified_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    return true if festival.user == user && status == "pending"
    false
  end

  def approve!(approver, approved_amount, notes = nil)
    return false unless can_be_modified_by?(approver)
    return false unless status == "pending"

    transaction do
      update!(
        status: "approved",
        approved_amount: approved_amount,
        notes: notes
      )

      budget_category.update!(budget_limit: approved_amount)
    end
  end

  def reject!(approver, reason)
    return false unless can_be_modified_by?(approver)
    return false unless status == "pending"
    return false if reason.blank?

    update!(
      status: "rejected",
      approved_amount: 0,
      notes: reason
    )
  end

  private

  def notify_approval_request
    festival.user&.then do |festival_manager|
      NotificationService.create_notification(
        recipient: festival_manager,
        sender: approver,
        notifiable: self,
        notification_type: "budget_approval_requested",
        title: "予算承認申請",
        message: "#{budget_category.name}: #{requested_amount_formatted}の承認申請"
      )
    end
  end

  def notify_approval_decision
    return unless %w[approved rejected].include?(status)

    notification_type = status == "approved" ? "budget_approval_approved" : "budget_approval_rejected"
    title = status == "approved" ? "予算が承認されました" : "予算申請が却下されました"

    festival.user&.then do |festival_manager|
      NotificationService.create_notification(
        recipient: festival_manager,
        sender: approver,
        notifiable: self,
        notification_type: notification_type,
        title: title,
        message: "#{budget_category.name}: #{approved_amount_formatted}"
      )
    end
  end
end
