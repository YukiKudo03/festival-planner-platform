# frozen_string_literal: true

# Permit Application model for managing government permits
# Handles the complete lifecycle of permit applications for festivals
class PermitApplication < ApplicationRecord
  # Associations
  belongs_to :festival
  belongs_to :municipal_authority
  belongs_to :submitted_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :permit_documents, dependent: :destroy
  has_many :permit_reviews, dependent: :destroy
  has_many :permit_status_changes, dependent: :destroy

  # Validations
  validates :permit_type, presence: true, inclusion: { in: PERMIT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :estimated_attendance, presence: true, numericality: { greater_than: 0 }
  validates :event_start_date, presence: true
  validates :event_end_date, presence: true
  validates :venue_address, presence: true
  validates :contact_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_phone, presence: true

  validate :end_date_after_start_date
  validate :application_submitted_in_advance
  validate :authority_has_jurisdiction

  # Enums
  enum status: {
    draft: "draft",
    submitted: "submitted",
    under_review: "under_review",
    additional_info_required: "additional_info_required",
    approved: "approved",
    rejected: "rejected",
    expired: "expired",
    cancelled: "cancelled"
  }

  enum priority: {
    low: "low",
    medium: "medium",
    high: "high",
    urgent: "urgent"
  }

  # Constants
  PERMIT_TYPES = %w[
    event_permit
    road_use_permit
    noise_permit
    security_plan_approval
    traffic_control_permit
    fire_safety_inspection
    emergency_access_approval
    food_safety_permit
    sanitation_plan_approval
    alcohol_service_permit
    temporary_structure_permit
    waste_management_permit
    environmental_impact_permit
  ].freeze

  STATUSES = %w[
    draft
    submitted
    under_review
    additional_info_required
    approved
    rejected
    expired
    cancelled
  ].freeze

  # Scopes
  scope :for_festival, ->(festival) { where(festival: festival) }
  scope :by_authority, ->(authority) { where(municipal_authority: authority) }
  scope :by_permit_type, ->(type) { where(permit_type: type) }
  scope :pending, -> { where(status: [ "submitted", "under_review", "additional_info_required" ]) }
  scope :completed, -> { where(status: [ "approved", "rejected" ]) }
  scope :requiring_action, -> { where(status: [ "submitted", "additional_info_required" ]) }
  scope :overdue, -> { where("expected_decision_date < ? AND status IN (?)", Date.current, [ "submitted", "under_review" ]) }

  # Callbacks
  before_create :set_application_number
  before_create :calculate_expected_decision_date
  after_create :create_initial_status_change
  after_update :track_status_changes, if: :saved_change_to_status?
  after_update :notify_stakeholders, if: :saved_change_to_status?

  # Instance methods

  # Returns human-readable permit type
  def permit_type_name
    permit_type.humanize.titleize
  end

  # Returns current processing days
  def processing_days
    return 0 unless submitted_at

    end_date = approved_at || rejected_at || Time.current
    (end_date.to_date - submitted_at.to_date).to_i
  end

  # Returns expected processing days based on permit type and authority
  def expected_processing_days
    municipal_authority.typical_processing_time(permit_type)[:business_days] || 14
  end

  # Checks if application is overdue
  def overdue?
    expected_decision_date && expected_decision_date < Date.current && pending?
  end

  # Returns days until expected decision
  def days_until_decision
    return nil unless expected_decision_date

    (expected_decision_date - Date.current).to_i
  end

  # Returns progress percentage
  def progress_percentage
    case status
    when "draft" then 0
    when "submitted" then 25
    when "under_review" then 50
    when "additional_info_required" then 40
    when "approved", "rejected" then 100
    when "cancelled", "expired" then 100
    else 0
    end
  end

  # Submits the application
  def submit!
    return false unless draft?

    transaction do
      update!(
        status: "submitted",
        submitted_at: Time.current,
        expected_decision_date: calculate_expected_decision_date
      )

      # Create submission notification
      PermitApplicationMailer.submitted(self).deliver_later

      # Create review assignment if authority has auto-assignment
      create_review_assignment if municipal_authority.auto_assign_reviews?
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Approves the application
  def approve!(reviewer, notes: nil)
    return false unless can_approve?

    transaction do
      update!(
        status: "approved",
        approved_at: Time.current,
        reviewed_by: reviewer,
        reviewer_notes: notes
      )

      create_permit_reviews.create!(
        reviewer: reviewer,
        decision: "approved",
        notes: notes,
        reviewed_at: Time.current
      )
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Rejects the application
  def reject!(reviewer, notes:)
    return false unless can_reject?

    transaction do
      update!(
        status: "rejected",
        rejected_at: Time.current,
        reviewed_by: reviewer,
        reviewer_notes: notes
      )

      permit_reviews.create!(
        reviewer: reviewer,
        decision: "rejected",
        notes: notes,
        reviewed_at: Time.current
      )
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Requests additional information
  def request_additional_info!(reviewer, requested_info:)
    return false unless under_review?

    transaction do
      update!(
        status: "additional_info_required",
        additional_info_requested: requested_info,
        info_requested_at: Time.current,
        reviewed_by: reviewer
      )

      permit_reviews.create!(
        reviewer: reviewer,
        decision: "additional_info_required",
        notes: requested_info,
        reviewed_at: Time.current
      )
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Provides additional information
  def provide_additional_info!(info_provided)
    return false unless additional_info_required?

    update!(
      status: "under_review",
      additional_info_provided: info_provided,
      info_provided_at: Time.current
    )
  end

  # Cancels the application
  def cancel!(reason: nil)
    return false if completed?

    update!(
      status: "cancelled",
      cancelled_at: Time.current,
      cancellation_reason: reason
    )
  end

  # Returns required documents for this permit type
  def required_documents
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

  # Checks if all required documents are uploaded
  def all_documents_uploaded?
    required_docs = required_documents
    uploaded_docs = permit_documents.pluck(:document_type)
    (required_docs - uploaded_docs).empty?
  end

  # Returns missing documents
  def missing_documents
    required_documents - permit_documents.pluck(:document_type)
  end

  # Checks if application can be approved
  def can_approve?
    [ "submitted", "under_review" ].include?(status) && all_documents_uploaded?
  end

  # Checks if application can be rejected
  def can_reject?
    [ "submitted", "under_review", "additional_info_required" ].include?(status)
  end

  # Returns fee amount for this permit
  def permit_fee
    calculate_permit_fee
  end

  # Checks if fee has been paid
  def fee_paid?
    permit_fee_paid_at.present?
  end

  # Records fee payment
  def record_fee_payment!(payment_reference: nil)
    update!(
      permit_fee_paid_at: Time.current,
      permit_fee_payment_reference: payment_reference
    )
  end

  # Returns application summary for display
  def summary
    {
      application_number: application_number,
      permit_type: permit_type_name,
      status: status.humanize,
      festival_name: festival.name,
      authority_name: municipal_authority.name,
      processing_days: processing_days,
      expected_decision_date: expected_decision_date,
      overdue: overdue?
    }
  end

  # Class methods
  class << self
    # Returns applications requiring attention
    def requiring_attention
      where(status: [ "submitted", "additional_info_required" ]).or(overdue)
    end

    # Returns statistics for reporting
    def statistics(period: 30.days)
      where(created_at: period.ago..Time.current).group(:status).count
    end

    # Returns average processing time by permit type
    def average_processing_time_by_type
      completed.group(:permit_type).average("EXTRACT(days FROM (COALESCE(approved_at, rejected_at) - submitted_at))")
    end

    # Finds applications that may expire soon
    def expiring_soon(days: 30)
      approved.where("approved_at < ?", days.days.ago)
        .where("approved_at + INTERVAL '1 year' < ?", days.days.from_now)
    end
  end

  private

  def end_date_after_start_date
    return unless event_start_date && event_end_date

    errors.add(:event_end_date, "must be after start date") if event_end_date < event_start_date
  end

  def application_submitted_in_advance
    return unless event_start_date

    min_advance_days = municipal_authority&.minimum_advance_days || 14
    if event_start_date < min_advance_days.days.from_now
      errors.add(:event_start_date, "must be at least #{min_advance_days} days in the future")
    end
  end

  def authority_has_jurisdiction
    return unless municipal_authority && venue_address

    unless municipal_authority.has_jurisdiction?(venue_address)
      errors.add(:municipal_authority, "does not have jurisdiction over the venue location")
    end
  end

  def set_application_number
    year = Date.current.year
    sequence = PermitApplication.where("created_at >= ?", Date.current.beginning_of_year).count + 1
    authority_code = municipal_authority.code || municipal_authority.id.to_s.rjust(3, "0")

    self.application_number = "PA#{year}#{authority_code}#{sequence.to_s.rjust(4, '0')}"
  end

  def calculate_expected_decision_date
    return nil unless submitted_at || will_save_change_to_submitted_at?

    submission_date = submitted_at || Time.current
    processing_days = expected_processing_days

    # Add business days (excluding weekends)
    business_days_added = 0
    current_date = submission_date.to_date

    while business_days_added < processing_days
      current_date += 1.day
      business_days_added += 1 unless current_date.saturday? || current_date.sunday?
    end

    current_date
  end

  def create_initial_status_change
    permit_status_changes.create!(
      from_status: nil,
      to_status: status,
      changed_by: submitted_by,
      notes: "Application created"
    )
  end

  def track_status_changes
    permit_status_changes.create!(
      from_status: status_before_last_save,
      to_status: status,
      changed_by: reviewed_by || submitted_by,
      notes: "Status changed to #{status.humanize}"
    )
  end

  def notify_stakeholders
    case status
    when "submitted"
      PermitApplicationMailer.submitted(self).deliver_later
      PermitApplicationMailer.received_by_authority(self).deliver_later
    when "approved"
      PermitApplicationMailer.approved(self).deliver_later
    when "rejected"
      PermitApplicationMailer.rejected(self).deliver_later
    when "additional_info_required"
      PermitApplicationMailer.additional_info_required(self).deliver_later
    end
  end

  def create_review_assignment
    # This would create a review assignment if the authority supports it
    # Implementation depends on the specific authority's workflow
  end

  def calculate_permit_fee
    base_fee = case permit_type
    when "event_permit"
                 estimated_attendance <= 500 ? 5000 : 10000
    when "fire_safety_inspection"
                 15000
    when "food_safety_permit"
                 8000
    when "security_plan_approval"
                 12000
    else
                 5000
    end

    # Apply multipliers based on attendance
    if estimated_attendance > 5000
      base_fee *= 2
    elsif estimated_attendance > 2000
      base_fee *= 1.5
    end

    base_fee
  end
end
