# frozen_string_literal: true

# Permit Document model for managing document attachments
# Handles file uploads and document requirements for permits
class PermitDocument < ApplicationRecord
  # Associations
  belongs_to :permit_application
  belongs_to :uploaded_by, class_name: "User"
  has_one_attached :file

  # Validations
  validates :document_type, presence: true
  validates :filename, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :content_type, presence: true
  validate :file_attachment_present
  validate :file_size_within_limit
  validate :allowed_content_type

  # Enums
  enum status: {
    pending_review: "pending_review",
    approved: "approved",
    rejected: "rejected",
    requires_replacement: "requires_replacement"
  }

  # Constants
  ALLOWED_CONTENT_TYPES = [
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "image/jpeg",
    "image/png",
    "image/gif"
  ].freeze

  MAX_FILE_SIZE = 10.megabytes

  DOCUMENT_TYPES = {
    "event_plan" => "実施計画書",
    "venue_contract" => "会場使用契約書",
    "insurance_certificate" => "保険証書",
    "floor_plan" => "会場図面",
    "emergency_evacuation_plan" => "避難計画図",
    "fire_equipment_list" => "消防設備一覧",
    "food_handler_certificates" => "食品取扱者証明書",
    "supplier_certifications" => "仕入先認証書",
    "menu_details" => "メニュー詳細",
    "security_plan" => "警備計画書",
    "staff_training_records" => "スタッフ研修記録",
    "emergency_procedures" => "緊急時対応手順書",
    "application_form" => "申請書",
    "supporting_documents" => "関連資料"
  }.freeze

  # Scopes
  scope :by_document_type, ->(type) { where(document_type: type) }
  scope :pending_review, -> { where(status: "pending_review") }
  scope :approved, -> { where(status: "approved") }
  scope :requires_action, -> { where(status: [ "pending_review", "requires_replacement" ]) }

  # Callbacks
  before_validation :extract_file_metadata, if: :file_attached?
  after_create :notify_upload_completion
  after_update :track_status_changes, if: :saved_change_to_status?

  # Instance methods

  # Returns human-readable document type
  def document_type_name
    DOCUMENT_TYPES[document_type] || document_type.humanize
  end

  # Returns file size in human-readable format
  def human_file_size
    return "0 B" if file_size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  # Checks if document is an image
  def image?
    content_type.start_with?("image/")
  end

  # Checks if document is a PDF
  def pdf?
    content_type == "application/pdf"
  end

  # Returns download URL
  def download_url
    return nil unless file.attached?

    Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
  end

  # Approves the document
  def approve!(reviewer, notes: nil)
    return false unless pending_review?

    update!(
      status: "approved",
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      review_notes: notes
    )

    # Check if all required documents for permit are now approved
    check_permit_document_completion

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Rejects the document
  def reject!(reviewer, reason:)
    return false unless pending_review?

    update!(
      status: "rejected",
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      rejection_reason: reason
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Requests document replacement
  def request_replacement!(reviewer, reason:)
    return false unless %w[pending_review approved].include?(status)

    update!(
      status: "requires_replacement",
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      replacement_reason: reason
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Returns processing days since upload
  def processing_days
    return 0 unless created_at

    end_date = reviewed_at || Time.current
    (end_date.to_date - created_at.to_date).to_i
  end

  # Checks if document review is overdue
  def review_overdue?
    return false unless pending_review?

    processing_days > 5 # Default 5 business days for document review
  end

  # Returns document summary
  def summary
    {
      id: id,
      document_type: document_type_name,
      filename: filename,
      file_size: human_file_size,
      status: status.humanize,
      uploaded_at: created_at,
      reviewed_at: reviewed_at,
      processing_days: processing_days
    }
  end

  # Class methods
  class << self
    # Returns documents requiring review
    def requiring_review
      where(status: [ "pending_review", "requires_replacement" ])
    end

    # Returns overdue document reviews
    def overdue_reviews
      pending_review.where("created_at < ?", 5.days.ago)
    end

    # Returns statistics for document processing
    def processing_statistics(period: 30.days)
      docs = where(created_at: period.ago..Time.current)

      {
        total_uploaded: docs.count,
        pending_review: docs.pending_review.count,
        approved: docs.approved.count,
        rejected: docs.where(status: "rejected").count,
        average_processing_days: docs.where.not(reviewed_at: nil).average("EXTRACT(days FROM (reviewed_at - created_at))"),
        approval_rate: docs.count > 0 ? (docs.approved.count.to_f / docs.count * 100).round(1) : 0
      }
    end

    # Import document requirements from template
    def import_requirements_template(permit_type)
      case permit_type
      when "event_permit"
        [ "event_plan", "venue_contract", "insurance_certificate" ]
      when "fire_safety_inspection"
        [ "floor_plan", "emergency_evacuation_plan", "fire_equipment_list" ]
      when "food_safety_permit"
        [ "food_handler_certificates", "supplier_certifications", "menu_details" ]
      when "security_plan_approval"
        [ "security_plan", "staff_training_records", "emergency_procedures" ]
      else
        [ "application_form", "supporting_documents" ]
      end
    end
  end

  private

  def file_attachment_present
    errors.add(:file, "must be attached") unless file.attached?
  end

  def file_size_within_limit
    return unless file.attached?

    if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, "size must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end

  def allowed_content_type
    return unless file.attached?

    unless ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "type is not allowed")
    end
  end

  def extract_file_metadata
    return unless file.attached?

    self.filename = file.blob.filename.to_s
    self.file_size = file.blob.byte_size
    self.content_type = file.blob.content_type
  end

  def notify_upload_completion
    PermitDocumentMailer.uploaded(self).deliver_later
  end

  def track_status_changes
    # Log status changes for audit trail
    Rails.logger.info "Document #{id} status changed from #{status_before_last_save} to #{status}"
  end

  def check_permit_document_completion
    permit = permit_application
    return unless permit

    if permit.all_documents_uploaded? && permit.permit_documents.all?(&:approved?)
      PermitApplicationMailer.all_documents_approved(permit).deliver_later
    end
  end
end
