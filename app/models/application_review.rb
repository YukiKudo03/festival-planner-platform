class ApplicationReview < ApplicationRecord
  belongs_to :vendor_application
  belongs_to :reviewer, class_name: "User"

  enum :action, {
    submitted: 0,
    started_review: 1,
    requested_changes: 2,
    conditionally_approved: 3,
    approved: 4,
    rejected: 5,
    withdrawn: 6
  }

  validates :comment, presence: true, if: -> { rejected? || requested_changes? }
  validates :conditions, presence: true, if: :conditionally_approved?
  validates :reviewed_at, presence: true, unless: :submitted?

  scope :recent, -> { order(created_at: :desc) }
  scope :by_reviewer, ->(reviewer) { where(reviewer: reviewer) }
  scope :by_action, ->(action) { where(action: action) }
  scope :pending_review, -> { where(action: [ :submitted, :started_review ]) }

  before_create :set_reviewed_at, unless: :submitted?

  def reviewer_name
    reviewer&.display_name || "システム"
  end

  def action_text
    case action
    when "submitted"
      "申請提出"
    when "started_review"
      "審査開始"
    when "requested_changes"
      "修正要求"
    when "conditionally_approved"
      "条件付き承認"
    when "approved"
      "承認"
    when "rejected"
      "却下"
    when "withdrawn"
      "取り下げ"
    else
      action.humanize
    end
  end

  private

  def set_reviewed_at
    self.reviewed_at = Time.current
  end
end
