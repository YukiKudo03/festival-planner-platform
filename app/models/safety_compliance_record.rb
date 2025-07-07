# frozen_string_literal: true

# Safety Compliance Record model for managing safety inspections
# Handles safety authority integration and compliance tracking
class SafetyComplianceRecord < ApplicationRecord
  # Associations
  belongs_to :festival
  belongs_to :municipal_authority
  belongs_to :inspector, class_name: 'User', optional: true
  belongs_to :submitted_by, class_name: 'User'
  has_many :safety_documents, dependent: :destroy
  has_many :safety_violations, dependent: :destroy
  has_many :safety_reviews, dependent: :destroy

  # Validations
  validates :compliance_type, presence: true, inclusion: { in: COMPLIANCE_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :inspection_date, presence: true
  validates :venue_address, presence: true
  validates :contact_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_phone, presence: true

  validate :inspection_date_in_future
  validate :authority_handles_compliance_type

  # Enums
  enum status: {
    scheduled: 'scheduled',
    in_progress: 'in_progress',
    completed: 'completed',
    passed: 'passed',
    failed: 'failed',
    conditional_pass: 'conditional_pass',
    cancelled: 'cancelled',
    rescheduled: 'rescheduled'
  }

  enum compliance_type: {
    fire_safety: 'fire_safety',
    structural_integrity: 'structural_integrity',
    electrical_safety: 'electrical_safety',
    crowd_control: 'crowd_control',
    emergency_preparedness: 'emergency_preparedness',
    food_safety: 'food_safety',
    noise_compliance: 'noise_compliance',
    environmental_impact: 'environmental_impact',
    accessibility_compliance: 'accessibility_compliance'
  }

  enum priority: {
    low: 'low',
    medium: 'medium',
    high: 'high',
    critical: 'critical'
  }

  # Constants
  COMPLIANCE_TYPES = %w[
    fire_safety
    structural_integrity
    electrical_safety
    crowd_control
    emergency_preparedness
    food_safety
    noise_compliance
    environmental_impact
    accessibility_compliance
  ].freeze

  STATUSES = %w[
    scheduled
    in_progress
    completed
    passed
    failed
    conditional_pass
    cancelled
    rescheduled
  ].freeze

  # JSON attributes
  serialize :inspection_checklist, Hash
  serialize :safety_requirements, Array
  serialize :compliance_standards, Hash
  serialize :remediation_plan, Hash
  serialize :follow_up_actions, Array

  # Scopes
  scope :by_compliance_type, ->(type) { where(compliance_type: type) }
  scope :by_authority, ->(authority) { where(municipal_authority: authority) }
  scope :pending_inspection, -> { where(status: ['scheduled', 'in_progress']) }
  scope :passed, -> { where(status: ['passed', 'conditional_pass']) }
  scope :failed, -> { where(status: 'failed') }
  scope :overdue, -> { where('inspection_date < ? AND status IN (?)', Date.current, ['scheduled', 'in_progress']) }
  scope :upcoming, -> { where('inspection_date BETWEEN ? AND ?', Date.current, 7.days.from_now) }

  # Callbacks
  before_create :set_record_number
  after_create :schedule_inspection_notification
  after_update :track_status_changes, if: :saved_change_to_status?
  after_update :notify_stakeholders, if: :saved_change_to_status?

  # Instance methods

  # Returns human-readable compliance type
  def compliance_type_name
    case compliance_type
    when 'fire_safety' then '消防安全'
    when 'structural_integrity' then '構造安全性'
    when 'electrical_safety' then '電気安全'
    when 'crowd_control' then '群衆制御'
    when 'emergency_preparedness' then '緊急時対応'
    when 'food_safety' then '食品安全'
    when 'noise_compliance' then '騒音規制'
    when 'environmental_impact' then '環境影響'
    when 'accessibility_compliance' then 'アクセシビリティ'
    else compliance_type.humanize
    end
  end

  # Returns inspection progress days
  def inspection_progress_days
    return 0 unless inspection_date
    
    if inspection_date > Date.current
      0  # Not started yet
    else
      (Date.current - inspection_date).to_i
    end
  end

  # Checks if inspection is overdue
  def overdue?
    inspection_date && inspection_date < Date.current && %w[scheduled in_progress].include?(status)
  end

  # Returns days until inspection
  def days_until_inspection
    return nil unless inspection_date
    
    (inspection_date - Date.current).to_i
  end

  # Returns progress percentage
  def progress_percentage
    case status
    when 'scheduled' then 0
    when 'in_progress' then 50
    when 'completed', 'passed', 'failed', 'conditional_pass' then 100
    when 'cancelled', 'rescheduled' then 0
    else 0
    end
  end

  # Starts the inspection
  def start_inspection!(inspector_user)
    return false unless scheduled?
    
    update!(
      status: 'in_progress',
      inspector: inspector_user,
      inspection_started_at: Time.current
    )
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Completes the inspection with results
  def complete_inspection!(inspector_user, result:, score: nil, notes: nil, violations: [])
    return false unless in_progress?
    
    transaction do
      # Update record status
      update!(
        status: 'completed',
        inspector: inspector_user,
        inspection_completed_at: Time.current,
        compliance_score: score,
        inspector_notes: notes
      )
      
      # Create violations if any
      violations.each do |violation_data|
        safety_violations.create!(
          violation_type: violation_data[:type],
          description: violation_data[:description],
          severity: violation_data[:severity],
          location: violation_data[:location],
          corrective_action_required: violation_data[:corrective_action]
        )
      end
      
      # Determine final status based on result
      final_status = case result
                    when 'pass' then 'passed'
                    when 'fail' then 'failed'
                    when 'conditional' then 'conditional_pass'
                    else 'completed'
                    end
      
      update!(status: final_status, final_result: result)
      
      # Create review record
      safety_reviews.create!(
        inspector: inspector_user,
        result: result,
        score: score,
        notes: notes,
        reviewed_at: Time.current
      )
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Fails the inspection
  def fail_inspection!(inspector_user, violations:, remediation_required: true)
    return false unless %w[in_progress completed].include?(status)
    
    transaction do
      update!(
        status: 'failed',
        inspector: inspector_user,
        final_result: 'fail',
        remediation_required: remediation_required
      )
      
      # Create violation records
      violations.each do |violation_data|
        safety_violations.create!(violation_data.merge(inspector: inspector_user))
      end
      
      # Schedule re-inspection if remediation is required
      if remediation_required
        schedule_reinspection
      end
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Reschedules the inspection
  def reschedule!(new_date, reason: nil)
    return false if %w[completed passed failed].include?(status)
    
    update!(
      status: 'rescheduled',
      inspection_date: new_date,
      reschedule_reason: reason,
      rescheduled_at: Time.current
    )
    
    # Update status back to scheduled for new date
    update!(status: 'scheduled')
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Cancels the inspection
  def cancel!(reason: nil)
    return false if %w[completed passed failed].include?(status)
    
    update!(
      status: 'cancelled',
      cancellation_reason: reason,
      cancelled_at: Time.current
    )
  end

  # Returns required documents for this compliance type
  def required_documents
    case compliance_type
    when 'fire_safety'
      ['floor_plan', 'fire_safety_plan', 'equipment_certificates']
    when 'structural_integrity'
      ['structural_plans', 'engineering_report', 'load_calculations']
    when 'electrical_safety'
      ['electrical_plans', 'equipment_certifications', 'safety_protocols']
    when 'crowd_control'
      ['crowd_management_plan', 'security_layout', 'staff_training_records']
    when 'emergency_preparedness'
      ['emergency_plan', 'evacuation_procedures', 'contact_list']
    else
      ['inspection_checklist', 'supporting_documents']
    end
  end

  # Checks if all required documents are uploaded
  def all_documents_uploaded?
    required_docs = required_documents
    uploaded_docs = safety_documents.pluck(:document_type)
    (required_docs - uploaded_docs).empty?
  end

  # Returns missing documents
  def missing_documents
    required_documents - safety_documents.pluck(:document_type)
  end

  # Returns compliance score color
  def score_color
    return 'gray' unless compliance_score
    
    case compliance_score
    when 90..100 then 'green'
    when 70..89 then 'yellow'
    when 50..69 then 'orange'
    else 'red'
    end
  end

  # Returns compliance status message
  def compliance_status_message
    case status
    when 'passed'
      'コンプライアンス基準を満たしています'
    when 'conditional_pass'
      '条件付きで基準を満たしています'
    when 'failed'
      'コンプライアンス基準を満たしていません'
    when 'in_progress'
      '検査実施中です'
    when 'scheduled'
      '検査予定です'
    else
      status.humanize
    end
  end

  # Returns record summary
  def summary
    {
      record_number: record_number,
      compliance_type: compliance_type_name,
      status: status.humanize,
      festival_name: festival.name,
      authority_name: municipal_authority.name,
      inspection_date: inspection_date,
      inspector_name: inspector&.name,
      compliance_score: compliance_score,
      violations_count: safety_violations.count,
      overdue: overdue?
    }
  end

  # Class methods
  class << self
    # Returns records requiring attention
    def requiring_attention
      where(status: ['scheduled', 'in_progress', 'failed']).or(overdue)
    end

    # Returns inspection statistics
    def inspection_statistics(period: 30.days)
      records = where(created_at: period.ago..Time.current)
      
      {
        total_inspections: records.count,
        pending_inspections: records.pending_inspection.count,
        passed_inspections: records.passed.count,
        failed_inspections: records.failed.count,
        overdue_inspections: records.overdue.count,
        average_score: records.where.not(compliance_score: nil).average(:compliance_score),
        pass_rate: records.count > 0 ? (records.passed.count.to_f / records.count * 100).round(1) : 0
      }
    end

    # Returns compliance rates by type
    def compliance_rates_by_type
      group(:compliance_type)
        .group(:status)
        .count
        .transform_keys { |k| { compliance_type: k[0], status: k[1] } }
    end

    # Finds records for festival
    def for_festival(festival)
      where(festival: festival)
    end

    # Returns critical violations
    def with_critical_violations
      joins(:safety_violations)
        .where(safety_violations: { severity: 'critical' })
        .distinct
    end
  end

  private

  def inspection_date_in_future
    return unless inspection_date
    
    if new_record? && inspection_date < Date.current
      errors.add(:inspection_date, 'must be in the future')
    end
  end

  def authority_handles_compliance_type
    return unless municipal_authority && compliance_type
    
    # Fire safety must be handled by fire department
    if compliance_type == 'fire_safety' && municipal_authority.authority_type != 'fire_department'
      errors.add(:municipal_authority, 'Fire safety inspections must be handled by fire department')
    end
    
    # Food safety must be handled by health department
    if compliance_type == 'food_safety' && municipal_authority.authority_type != 'health_department'
      errors.add(:municipal_authority, 'Food safety inspections must be handled by health department')
    end
  end

  def set_record_number
    year = Date.current.year
    sequence = SafetyComplianceRecord.where('created_at >= ?', Date.current.beginning_of_year).count + 1
    authority_code = municipal_authority.code || municipal_authority.id.to_s.rjust(3, '0')
    type_code = compliance_type.first(2).upcase
    
    self.record_number = "SC#{year}#{authority_code}#{type_code}#{sequence.to_s.rjust(4, '0')}"
  end

  def schedule_inspection_notification
    SafetyComplianceMailer.inspection_scheduled(self).deliver_later
  end

  def track_status_changes
    Rails.logger.info "Safety compliance record #{id} status changed from #{status_before_last_save} to #{status}"
  end

  def notify_stakeholders
    case status
    when 'in_progress'
      SafetyComplianceMailer.inspection_started(self).deliver_later
    when 'passed'
      SafetyComplianceMailer.inspection_passed(self).deliver_later
    when 'failed'
      SafetyComplianceMailer.inspection_failed(self).deliver_later
    when 'conditional_pass'
      SafetyComplianceMailer.conditional_pass(self).deliver_later
    when 'rescheduled'
      SafetyComplianceMailer.inspection_rescheduled(self).deliver_later
    end
  end

  def schedule_reinspection
    reinspection_date = 30.days.from_now # Default 30 days for remediation
    
    SafetyComplianceRecord.create!(
      festival: festival,
      municipal_authority: municipal_authority,
      submitted_by: submitted_by,
      compliance_type: compliance_type,
      inspection_date: reinspection_date,
      venue_address: venue_address,
      contact_name: contact_name,
      contact_email: contact_email,
      contact_phone: contact_phone,
      priority: 'high',
      status: 'scheduled',
      parent_record_id: id
    )
  end
end