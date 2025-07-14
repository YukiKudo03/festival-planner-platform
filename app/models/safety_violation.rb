# frozen_string_literal: true

# Safety Violation model for tracking compliance violations
# Handles safety inspection violations and remediation tracking
class SafetyViolation < ApplicationRecord
  # Associations
  belongs_to :safety_compliance_record
  belongs_to :inspector, class_name: "User"
  has_many :violation_photos, dependent: :destroy
  has_many :remediation_actions, dependent: :destroy

  # Validations
  validates :violation_type, presence: true
  validates :description, presence: true
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :location, presence: true

  # Enums
  enum severity: {
    minor: "minor",
    moderate: "moderate",
    major: "major",
    critical: "critical"
  }

  enum status: {
    open: "open",
    in_remediation: "in_remediation",
    resolved: "resolved",
    verified: "verified",
    dismissed: "dismissed"
  }

  enum violation_type: {
    structural_defect: "structural_defect",
    fire_hazard: "fire_hazard",
    electrical_issue: "electrical_issue",
    crowd_safety: "crowd_safety",
    emergency_access: "emergency_access",
    food_contamination: "food_contamination",
    noise_violation: "noise_violation",
    environmental_hazard: "environmental_hazard",
    accessibility_barrier: "accessibility_barrier",
    documentation_missing: "documentation_missing"
  }

  # Constants
  SEVERITIES = %w[minor moderate major critical].freeze
  STATUSES = %w[open in_remediation resolved verified dismissed].freeze

  VIOLATION_TYPES = {
    "structural_defect" => "構造的欠陥",
    "fire_hazard" => "火災危険",
    "electrical_issue" => "電気的問題",
    "crowd_safety" => "群衆安全",
    "emergency_access" => "緊急時アクセス",
    "food_contamination" => "食品汚染",
    "noise_violation" => "騒音違反",
    "environmental_hazard" => "環境危険",
    "accessibility_barrier" => "アクセシビリティ障壁",
    "documentation_missing" => "書類不備"
  }.freeze

  # JSON attributes
  serialize :corrective_actions, Array
  serialize :compliance_requirements, Hash
  serialize :remediation_timeline, Hash

  # Scopes
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :by_type, ->(type) { where(violation_type: type) }
  scope :critical, -> { where(severity: "critical") }
  scope :major, -> { where(severity: [ "major", "critical" ]) }
  scope :open_violations, -> { where(status: "open") }
  scope :unresolved, -> { where(status: [ "open", "in_remediation" ]) }
  scope :overdue_remediation, -> { where("remediation_deadline < ? AND status IN (?)", Date.current, [ "open", "in_remediation" ]) }

  # Callbacks
  before_create :set_violation_number
  before_create :calculate_remediation_deadline
  after_create :notify_violation_detected
  after_update :track_status_changes, if: :saved_change_to_status?
  after_update :notify_status_change, if: :saved_change_to_status?

  # Instance methods

  # Returns human-readable violation type
  def violation_type_name
    VIOLATION_TYPES[violation_type] || violation_type.humanize
  end

  # Returns severity color for UI
  def severity_color
    case severity
    when "minor" then "green"
    when "moderate" then "yellow"
    when "major" then "orange"
    when "critical" then "red"
    else "gray"
    end
  end

  # Returns severity priority score
  def severity_score
    case severity
    when "minor" then 1
    when "moderate" then 2
    when "major" then 3
    when "critical" then 4
    else 0
    end
  end

  # Returns days since violation was detected
  def days_since_detection
    (Date.current - created_at.to_date).to_i
  end

  # Returns days until remediation deadline
  def days_until_deadline
    return nil unless remediation_deadline

    (remediation_deadline - Date.current).to_i
  end

  # Checks if remediation is overdue
  def overdue?
    remediation_deadline && remediation_deadline < Date.current && unresolved?
  end

  # Checks if violation is unresolved
  def unresolved?
    %w[open in_remediation].include?(status)
  end

  # Starts remediation process
  def start_remediation!(remediation_plan:, assigned_to: nil)
    return false unless open?

    update!(
      status: "in_remediation",
      remediation_started_at: Time.current,
      assigned_to: assigned_to,
      remediation_plan: remediation_plan
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Resolves the violation
  def resolve!(resolved_by:, resolution_notes:, verification_required: true)
    return false unless %w[open in_remediation].include?(status)

    new_status = verification_required ? "resolved" : "verified"

    update!(
      status: new_status,
      resolved_at: Time.current,
      resolved_by: resolved_by,
      resolution_notes: resolution_notes
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Verifies the resolution
  def verify_resolution!(verified_by:, verification_notes: nil)
    return false unless resolved?

    update!(
      status: "verified",
      verified_at: Time.current,
      verified_by: verified_by,
      verification_notes: verification_notes
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Dismisses the violation (false positive)
  def dismiss!(dismissed_by:, dismissal_reason:)
    return false if verified?

    update!(
      status: "dismissed",
      dismissed_at: Time.current,
      dismissed_by: dismissed_by,
      dismissal_reason: dismissal_reason
    )

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Returns progress percentage
  def progress_percentage
    case status
    when "open" then 0
    when "in_remediation" then 50
    when "resolved" then 80
    when "verified" then 100
    when "dismissed" then 100
    else 0
    end
  end

  # Returns estimated remediation time based on severity
  def estimated_remediation_days
    case severity
    when "critical" then 1
    when "major" then 7
    when "moderate" then 14
    when "minor" then 30
    else 14
    end
  end

  # Returns priority rank for sorting
  def priority_rank
    # Combine severity and time factors
    base_score = severity_score * 100
    time_factor = overdue? ? 200 : (days_since_detection * 2)

    base_score + time_factor
  end

  # Returns remediation status message
  def remediation_status_message
    case status
    when "open"
      overdue? ? "期限超過：緊急対応が必要" : "対応待ち"
    when "in_remediation"
      "改善作業中"
    when "resolved"
      "改善完了：検証待ち"
    when "verified"
      "改善完了：検証済み"
    when "dismissed"
      "無効：誤検出"
    else
      status.humanize
    end
  end

  # Returns violation summary
  def summary
    {
      violation_number: violation_number,
      violation_type: violation_type_name,
      severity: severity.upcase,
      status: status.humanize,
      location: location,
      description: description,
      days_since_detection: days_since_detection,
      days_until_deadline: days_until_deadline,
      overdue: overdue?,
      progress_percentage: progress_percentage
    }
  end

  # Class methods
  class << self
    # Returns violations requiring immediate attention
    def critical_violations
      where(severity: "critical", status: [ "open", "in_remediation" ])
    end

    # Returns overdue violations
    def overdue_violations
      overdue_remediation
    end

    # Returns statistics for violations
    def violation_statistics(period: 30.days)
      violations = where(created_at: period.ago..Time.current)

      {
        total_violations: violations.count,
        by_severity: violations.group(:severity).count,
        by_type: violations.group(:violation_type).count,
        by_status: violations.group(:status).count,
        critical_open: violations.critical.open_violations.count,
        overdue_count: violations.overdue_remediation.count,
        resolution_rate: violations.count > 0 ? (violations.where(status: [ "verified", "dismissed" ]).count.to_f / violations.count * 100).round(1) : 0,
        average_resolution_days: violations.where.not(resolved_at: nil).average("EXTRACT(days FROM (resolved_at - created_at))")
      }
    end

    # Returns violations by compliance record
    def for_compliance_record(record)
      where(safety_compliance_record: record)
    end

    # Returns violations requiring verification
    def pending_verification
      where(status: "resolved")
    end

    # Import violations from inspection checklist
    def import_from_checklist(compliance_record, checklist_data, inspector)
      violations_created = 0

      checklist_data.each do |item|
        next unless item[:status] == "fail" || item[:violation]

        violation = create!(
          safety_compliance_record: compliance_record,
          inspector: inspector,
          violation_type: map_checklist_item_to_type(item[:category]),
          description: item[:description] || item[:notes],
          severity: determine_severity(item),
          location: item[:location] || "General",
          corrective_actions: item[:corrective_actions] || [],
          status: "open"
        )

        violations_created += 1 if violation.persisted?
      end

      violations_created
    end

    private

    def map_checklist_item_to_type(category)
      case category.to_s.downcase
      when "fire", "fire_safety" then "fire_hazard"
      when "electrical", "power" then "electrical_issue"
      when "structure", "building" then "structural_defect"
      when "crowd", "people" then "crowd_safety"
      when "emergency", "evacuation" then "emergency_access"
      when "food", "sanitation" then "food_contamination"
      when "noise", "sound" then "noise_violation"
      when "environment", "environmental" then "environmental_hazard"
      when "accessibility", "ada" then "accessibility_barrier"
      else "documentation_missing"
      end
    end

    def determine_severity(item)
      # Determine severity based on item attributes
      if item[:critical] || item[:severity] == "critical"
        "critical"
      elsif item[:major] || item[:severity] == "major"
        "major"
      elsif item[:moderate] || item[:severity] == "moderate"
        "moderate"
      else
        "minor"
      end
    end
  end

  private

  def set_violation_number
    record_number = safety_compliance_record.record_number
    sequence = safety_compliance_record.safety_violations.count + 1

    self.violation_number = "#{record_number}-V#{sequence.to_s.rjust(3, '0')}"
  end

  def calculate_remediation_deadline
    self.remediation_deadline = created_at.to_date + estimated_remediation_days.days
  end

  def notify_violation_detected
    SafetyViolationMailer.violation_detected(self).deliver_later

    # Send urgent notification for critical violations
    if critical?
      SafetyViolationMailer.critical_violation_alert(self).deliver_later
    end
  end

  def track_status_changes
    Rails.logger.info "Safety violation #{id} status changed from #{status_before_last_save} to #{status}"
  end

  def notify_status_change
    case status
    when "in_remediation"
      SafetyViolationMailer.remediation_started(self).deliver_later
    when "resolved"
      SafetyViolationMailer.violation_resolved(self).deliver_later
    when "verified"
      SafetyViolationMailer.resolution_verified(self).deliver_later
    when "dismissed"
      SafetyViolationMailer.violation_dismissed(self).deliver_later
    end
  end
end
