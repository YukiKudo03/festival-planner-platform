class VendorApplication < ApplicationRecord
  belongs_to :festival
  belongs_to :user

  enum :status, {
    draft: 0,
    submitted: 1,
    under_review: 2,
    requires_changes: 3,
    conditionally_approved: 4,
    approved: 5,
    rejected: 6,
    withdrawn: 7,
    cancelled: 8
  }

  enum :priority, {
    low: 1,
    medium: 2,
    high: 3,
    urgent: 4
  }

  validates :business_name, :business_type, :description, presence: true
  validates :business_name, length: { maximum: 100 }
  validates :business_type, length: { maximum: 50 }
  validates :description, length: { maximum: 2000 }
  validates :requirements, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: { scope: :festival_id, message: "can only apply once per festival" }

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  # 関連
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :application_reviews, dependent: :destroy
  has_many :application_comments, dependent: :destroy
  has_many :reviewers, through: :application_reviews, source: :reviewer

  # Active Storage attachments
  has_many_attached :documents
  has_many_attached :business_documents
  has_one_attached :business_license

  # コールバック
  after_create :create_initial_review
  after_update :send_status_change_notification

  # ワークフロー管理
  def can_be_submitted?
    draft?
  end

  def can_be_reviewed?
    submitted? || requires_changes?
  end

  def can_be_approved?
    submitted? || under_review? || requires_changes?
  end

  def can_be_rejected?
    submitted? || under_review? || requires_changes?
  end

  def can_request_changes?
    submitted? || under_review?
  end

  def can_be_withdrawn?
    !withdrawn? && !cancelled? && !approved?
  end

  # ステータス変更
  def submit!(user = nil)
    return false unless can_be_submitted?

    transaction do
      update!(
        status: :submitted,
        submitted_at: Time.current,
        review_deadline: festival.start_date - 30.days # デフォルト30日前
      )

      application_reviews.create!(
        reviewer: user || self.user,
        action: :submitted,
        reviewed_at: Time.current
      )
    end
  end

  def start_review!(reviewer)
    return false unless can_be_reviewed?

    transaction do
      update!(status: :under_review)
      application_reviews.create!(
        reviewer: reviewer,
        action: :started_review,
        reviewed_at: Time.current
      )
    end
  end

  def approve!(reviewer, comment = nil)
    return false unless can_be_approved?

    transaction do
      update!(
        status: :approved,
        reviewed_at: Time.current
      )

      application_reviews.create!(
        reviewer: reviewer,
        action: :approved,
        comment: comment,
        reviewed_at: Time.current
      )
    end
  end

  def reject!(reviewer, comment)
    return false unless can_be_rejected?
    return false if comment.blank?

    transaction do
      update!(
        status: :rejected,
        reviewed_at: Time.current
      )

      application_reviews.create!(
        reviewer: reviewer,
        action: :rejected,
        comment: comment,
        reviewed_at: Time.current
      )
    end
  end

  def request_changes!(reviewer, comment)
    return false unless can_request_changes?
    return false if comment.blank?

    transaction do
      update!(status: :requires_changes)
      application_reviews.create!(
        reviewer: reviewer,
        action: :requested_changes,
        comment: comment,
        reviewed_at: Time.current
      )
    end
  end

  def conditionally_approve!(reviewer, conditions, comment = nil)
    return false unless can_be_approved?
    return false if conditions.blank?

    transaction do
      update!(
        status: :conditionally_approved,
        reviewed_at: Time.current
      )

      application_reviews.create!(
        reviewer: reviewer,
        action: :conditionally_approved,
        comment: comment,
        conditions: conditions,
        reviewed_at: Time.current
      )
    end
  end

  def withdraw!(user = nil)
    return false unless can_be_withdrawn?

    transaction do
      update!(status: :withdrawn)
      application_reviews.create!(
        reviewer: user || self.user,
        action: :withdrawn,
        reviewed_at: Time.current
      )
    end
  end

  # ステータス表示
  def status_text
    case status
    when "draft" then "下書き"
    when "submitted" then "提出済み"
    when "under_review" then "審査中"
    when "requires_changes" then "修正要求"
    when "conditionally_approved" then "条件付き承認"
    when "approved" then "承認"
    when "rejected" then "却下"
    when "withdrawn" then "取り下げ"
    when "cancelled" then "キャンセル"
    else status.humanize
    end
  end

  def status_color
    case status
    when "draft" then "secondary"
    when "submitted" then "info"
    when "under_review" then "warning"
    when "requires_changes" then "warning"
    when "conditionally_approved" then "primary"
    when "approved" then "success"
    when "rejected" then "danger"
    when "withdrawn" then "secondary"
    when "cancelled" then "dark"
    else "secondary"
    end
  end

  def priority_text
    case priority
    when "low" then "低"
    when "medium" then "中"
    when "high" then "高"
    when "urgent" then "緊急"
    else priority.humanize
    end
  end

  # 期限管理
  def submission_overdue?
    submission_deadline && submission_deadline < Time.current && !submitted?
  end

  def review_overdue?
    review_deadline && review_deadline < Time.current && !reviewed?
  end

  def reviewed?
    approved? || rejected? || withdrawn? || cancelled?
  end

  # 最新レビュー
  def latest_review
    application_reviews.recent.first
  end

  # 公開コメント
  def public_comments
    application_comments.public_comments.recent
  end

  # 内部コメント（管理者のみ）
  def internal_comments
    application_comments.internal_comments.recent
  end

  private

  def create_initial_review
    # 作成時にsubmittedレビューを自動作成（下書きの場合はスキップ）
    return if draft?

    application_reviews.create!(
      reviewer: user,
      action: :submitted,
      reviewed_at: Time.current
    )
  end

  def send_status_change_notification
    if saved_change_to_status?
      case status
      when "submitted"
        NotificationService.send_vendor_application_submitted_notification(self)
      when "approved", "rejected", "conditionally_approved"
        NotificationService.send_vendor_application_status_notification(self, status)
      when "requires_changes"
        NotificationService.send_vendor_application_changes_requested(self)
      end
    end
  end
end
