# frozen_string_literal: true

# Subsidy Application model for managing subsidy requests
# Handles the complete lifecycle of subsidy applications from festivals
class SubsidyApplication < ApplicationRecord
  # Associations
  belongs_to :festival
  belongs_to :subsidy_program
  belongs_to :submitted_by, class_name: 'User'
  belongs_to :reviewed_by, class_name: 'User', optional: true
  has_many :subsidy_documents, dependent: :destroy
  has_many :subsidy_reviews, dependent: :destroy
  has_many :subsidy_status_changes, dependent: :destroy
  has_many :subsidy_payments, dependent: :destroy

  # Validations
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :requested_amount, presence: true, numericality: { greater_than: 0 }
  validates :project_description, presence: true
  validates :expected_outcomes, presence: true
  validates :contact_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_phone, presence: true

  validate :amount_within_program_limits
  validate :festival_eligible_for_program
  validate :application_within_deadline

  # Enums
  enum status: {
    draft: 'draft',
    submitted: 'submitted',
    under_review: 'under_review',
    additional_info_required: 'additional_info_required',
    approved: 'approved',
    rejected: 'rejected',
    withdrawn: 'withdrawn'
  }

  enum funding_stage: {
    pre_event: 'pre_event',
    during_event: 'during_event',
    post_event: 'post_event'
  }

  # Constants
  STATUSES = %w[
    draft
    submitted
    under_review
    additional_info_required
    approved
    rejected
    withdrawn
  ].freeze

  # JSON attributes
  serialize :project_timeline, Hash
  serialize :budget_breakdown, Hash
  serialize :performance_indicators, Array
  serialize :community_impact_metrics, Hash
  serialize :risk_mitigation_plan, Hash

  # Scopes
  scope :for_festival, ->(festival) { where(festival: festival) }
  scope :by_program, ->(program) { where(subsidy_program: program) }
  scope :pending, -> { where(status: ['submitted', 'under_review', 'additional_info_required']) }
  scope :approved, -> { where(status: 'approved') }
  scope :completed, -> { where(status: ['approved', 'rejected']) }
  scope :by_amount_range, ->(min, max) { where(requested_amount: min..max) }

  # Callbacks
  before_create :set_application_number
  before_create :calculate_review_deadline
  after_create :create_initial_status_change
  after_update :track_status_changes, if: :saved_change_to_status?
  after_update :notify_stakeholders, if: :saved_change_to_status?

  # Instance methods

  # Returns application processing days
  def processing_days
    return 0 unless submitted_at
    
    end_date = approved_at || rejected_at || Time.current
    (end_date.to_date - submitted_at.to_date).to_i
  end

  # Checks if application is overdue for review
  def overdue?
    review_deadline && review_deadline < Date.current && pending?
  end

  # Returns days until review deadline
  def days_until_deadline
    return nil unless review_deadline
    
    (review_deadline - Date.current).to_i
  end

  # Returns progress percentage
  def progress_percentage
    case status
    when 'draft' then 0
    when 'submitted' then 25
    when 'under_review' then 50
    when 'additional_info_required' then 40
    when 'approved', 'rejected' then 100
    when 'withdrawn' then 100
    else 0
    end
  end

  # Submits the application
  def submit!
    return false unless draft?
    
    transaction do
      update!(
        status: 'submitted',
        submitted_at: Time.current,
        review_deadline: calculate_review_deadline
      )
      
      # Send notification emails
      SubsidyApplicationMailer.submitted(self).deliver_later
      SubsidyApplicationMailer.received_by_authority(self).deliver_later
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Approves the application
  def approve!(reviewer, granted_amount:, conditions: nil, notes: nil)
    return false unless can_approve?
    
    transaction do
      update!(
        status: 'approved',
        approved_at: Time.current,
        reviewed_by: reviewer,
        granted_amount: granted_amount,
        approval_conditions: conditions,
        reviewer_notes: notes
      )
      
      subsidy_reviews.create!(
        reviewer: reviewer,
        decision: 'approved',
        granted_amount: granted_amount,
        notes: notes,
        reviewed_at: Time.current
      )
      
      # Update program remaining budget
      subsidy_program.update_budget_utilization!
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Rejects the application
  def reject!(reviewer, reason:, notes: nil)
    return false unless can_reject?
    
    transaction do
      update!(
        status: 'rejected',
        rejected_at: Time.current,
        reviewed_by: reviewer,
        rejection_reason: reason,
        reviewer_notes: notes
      )
      
      subsidy_reviews.create!(
        reviewer: reviewer,
        decision: 'rejected',
        rejection_reason: reason,
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
        status: 'additional_info_required',
        additional_info_requested: requested_info,
        info_requested_at: Time.current,
        reviewed_by: reviewer
      )
      
      subsidy_reviews.create!(
        reviewer: reviewer,
        decision: 'additional_info_required',
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
      status: 'under_review',
      additional_info_provided: info_provided,
      info_provided_at: Time.current
    )
  end

  # Withdraws the application
  def withdraw!(reason: nil)
    return false if completed?
    
    update!(
      status: 'withdrawn',
      withdrawn_at: Time.current,
      withdrawal_reason: reason
    )
  end

  # Returns required documents for this subsidy program
  def required_documents
    subsidy_program.formatted_requirements
  end

  # Checks if all required documents are uploaded
  def all_documents_uploaded?
    required_docs = required_documents
    uploaded_docs = subsidy_documents.pluck(:document_type)
    (required_docs - uploaded_docs).empty?
  end

  # Returns missing documents
  def missing_documents
    required_documents - subsidy_documents.pluck(:document_type)
  end

  # Checks if application can be approved
  def can_approve?
    ['submitted', 'under_review'].include?(status) && all_documents_uploaded?
  end

  # Checks if application can be rejected
  def can_reject?
    ['submitted', 'under_review', 'additional_info_required'].include?(status)
  end

  # Calculates grant amount based on program rules
  def calculated_grant_amount
    subsidy_program.calculate_grant_amount(festival.total_budget, requested_amount)
  end

  # Returns budget breakdown as percentage
  def budget_breakdown_percentage
    return {} unless budget_breakdown.present? && festival.total_budget.present?
    
    total = festival.total_budget
    breakdown_percentage = {}
    
    budget_breakdown.each do |category, amount|
      breakdown_percentage[category] = (amount.to_f / total * 100).round(2)
    end
    
    breakdown_percentage
  end

  # Returns expected impact score
  def impact_score
    score = 0
    
    # Community impact (40%)
    if community_impact_metrics.present?
      score += (community_impact_metrics['expected_attendees'].to_i / 1000.0 * 40).clamp(0, 40)
    end
    
    # Innovation factor (20%)
    if project_description.include?('革新') || project_description.include?('新しい')
      score += 20
    end
    
    # Sustainability (20%)
    if project_description.include?('持続可能') || project_description.include?('環境')
      score += 20
    end
    
    # Cultural value (20%)
    if project_description.include?('文化') || project_description.include?('伝統')
      score += 20
    end
    
    score.clamp(0, 100)
  end

  # Returns application summary
  def summary
    {
      application_number: application_number,
      festival_name: festival.name,
      program_name: subsidy_program.name,
      requested_amount: "¥#{requested_amount.to_s(:delimited)}",
      granted_amount: granted_amount ? "¥#{granted_amount.to_s(:delimited)}" : nil,
      status: status.humanize,
      processing_days: processing_days,
      review_deadline: review_deadline,
      overdue: overdue?
    }
  end

  # Class methods
  class << self
    # Returns applications requiring attention
    def requiring_attention
      where(status: ['submitted', 'additional_info_required']).or(overdue)
    end

    # Returns statistics for reporting
    def statistics(period: 30.days)
      apps = where(created_at: period.ago..Time.current)
      
      {
        total_applications: apps.count,
        pending_applications: apps.pending.count,
        approved_applications: apps.approved.count,
        rejected_applications: apps.where(status: 'rejected').count,
        total_requested: apps.sum(:requested_amount),
        total_granted: apps.approved.sum(:granted_amount),
        average_processing_days: apps.completed.average('EXTRACT(days FROM (COALESCE(approved_at, rejected_at) - submitted_at))'),
        success_rate: apps.count > 0 ? (apps.approved.count.to_f / apps.count * 100).round(1) : 0
      }
    end

    # Returns average grant amounts by category
    def average_grants_by_category
      joins(:subsidy_program)
        .approved
        .group('subsidy_programs.priority_category')
        .average(:granted_amount)
    end

    # Finds applications expiring soon
    def deadline_approaching(days: 7)
      pending.where('review_deadline <= ?', days.days.from_now)
    end
  end

  private

  def amount_within_program_limits
    return unless requested_amount && subsidy_program
    
    if requested_amount < subsidy_program.min_grant_amount
      errors.add(:requested_amount, "must be at least ¥#{subsidy_program.min_grant_amount.to_s(:delimited)}")
    end
    
    if requested_amount > subsidy_program.max_grant_amount
      errors.add(:requested_amount, "cannot exceed ¥#{subsidy_program.max_grant_amount.to_s(:delimited)}")
    end
    
    if requested_amount > subsidy_program.remaining_budget
      errors.add(:requested_amount, 'exceeds remaining program budget')
    end
  end

  def festival_eligible_for_program
    return unless festival && subsidy_program
    
    unless subsidy_program.eligible_for_festival?(festival)
      errors.add(:festival, 'is not eligible for this subsidy program')
    end
  end

  def application_within_deadline
    return unless subsidy_program
    
    unless subsidy_program.accepting_applications?
      errors.add(:base, 'This subsidy program is not currently accepting applications')
    end
  end

  def set_application_number
    year = Date.current.year
    sequence = SubsidyApplication.where('created_at >= ?', Date.current.beginning_of_year).count + 1
    program_code = subsidy_program.id.to_s.rjust(3, '0')
    
    self.application_number = "SA#{year}#{program_code}#{sequence.to_s.rjust(4, '0')}"
  end

  def calculate_review_deadline
    return nil unless submitted_at || will_save_change_to_submitted_at?
    
    submission_date = submitted_at || Time.current
    review_period = subsidy_program.review_period_days || 30
    
    # Add business days (excluding weekends)
    business_days_added = 0
    current_date = submission_date.to_date
    
    while business_days_added < review_period
      current_date += 1.day
      business_days_added += 1 unless current_date.saturday? || current_date.sunday?
    end
    
    current_date
  end

  def create_initial_status_change
    subsidy_status_changes.create!(
      from_status: nil,
      to_status: status,
      changed_by: submitted_by,
      notes: 'Application created'
    )
  end

  def track_status_changes
    subsidy_status_changes.create!(
      from_status: status_before_last_save,
      to_status: status,
      changed_by: reviewed_by || submitted_by,
      notes: "Status changed to #{status.humanize}"
    )
  end

  def notify_stakeholders
    case status
    when 'submitted'
      SubsidyApplicationMailer.submitted(self).deliver_later
      SubsidyApplicationMailer.received_by_authority(self).deliver_later
    when 'approved'
      SubsidyApplicationMailer.approved(self).deliver_later
    when 'rejected'
      SubsidyApplicationMailer.rejected(self).deliver_later
    when 'additional_info_required'
      SubsidyApplicationMailer.additional_info_required(self).deliver_later
    end
  end
end