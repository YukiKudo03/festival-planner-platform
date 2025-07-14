# frozen_string_literal: true

# Subsidy Program model for managing government financial assistance
# Handles subsidies and grants available to festival organizers
class SubsidyProgram < ApplicationRecord
  # Associations
  belongs_to :municipal_authority
  has_many :subsidy_applications, dependent: :destroy
  has_many :festivals, through: :subsidy_applications

  # Validations
  validates :name, presence: true
  validates :description, presence: true
  validates :total_budget, presence: true, numericality: { greater_than: 0 }
  validates :max_grant_amount, presence: true, numericality: { greater_than: 0 }
  validates :min_grant_amount, presence: true, numericality: { greater_than: 0 }
  validates :application_start_date, presence: true
  validates :application_end_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  validate :end_date_after_start_date
  validate :grant_amounts_logical
  validate :total_budget_sufficient

  # Enums
  enum status: {
    planned: "planned",
    active: "active",
    suspended: "suspended",
    closed: "closed",
    completed: "completed"
  }

  enum grant_type: {
    percentage_based: "percentage_based",
    fixed_amount: "fixed_amount",
    matching_funds: "matching_funds",
    reimbursement: "reimbursement"
  }

  enum priority_category: {
    cultural_promotion: "cultural_promotion",
    tourism_development: "tourism_development",
    community_development: "community_development",
    economic_revitalization: "economic_revitalization",
    youth_engagement: "youth_engagement",
    accessibility_improvement: "accessibility_improvement",
    environmental_sustainability: "environmental_sustainability"
  }

  # Constants
  STATUSES = %w[planned active suspended closed completed].freeze

  ELIGIBLE_FESTIVAL_TYPES = %w[
    cultural_festival
    music_festival
    food_festival
    art_festival
    sports_festival
    community_festival
    religious_festival
    seasonal_festival
    educational_festival
    charity_festival
  ].freeze

  # JSON attributes
  serialize :eligible_festival_types, Array
  serialize :required_criteria, Array
  serialize :application_requirements, Hash
  serialize :evaluation_criteria, Hash

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :accepting_applications, -> { active.where("application_start_date <= ? AND application_end_date >= ?", Date.current, Date.current) }
  scope :by_authority, ->(authority) { where(municipal_authority: authority) }
  scope :for_festival_type, ->(type) { where("eligible_festival_types @> ?", [ type ].to_json) }
  scope :budget_range, ->(min, max) { where(min_grant_amount: min..max).or(where(max_grant_amount: min..max)) }

  # Callbacks
  before_save :calculate_remaining_budget
  after_update :notify_applicants_of_changes, if: :saved_change_to_status?

  # Instance methods

  # Checks if applications are currently being accepted
  def accepting_applications?
    active? &&
      Date.current >= application_start_date &&
      Date.current <= application_end_date &&
      remaining_budget > 0
  end

  # Returns remaining budget
  def remaining_budget
    total_budget - granted_amount
  end

  # Returns total amount granted so far
  def granted_amount
    subsidy_applications.approved.sum(:granted_amount)
  end

  # Returns budget utilization percentage
  def budget_utilization_percentage
    return 0 if total_budget.zero?

    (granted_amount.to_f / total_budget * 100).round(2)
  end

  # Checks if a festival is eligible for this program
  def eligible_for_festival?(festival)
    return false unless accepting_applications?

    # Check festival type eligibility
    return false unless eligible_festival_types.empty? ||
                       eligible_festival_types.include?(festival.category)

    # Check budget requirements
    estimated_budget = festival.total_budget || 0
    return false if min_festival_budget && estimated_budget < min_festival_budget
    return false if max_festival_budget && estimated_budget > max_festival_budget

    # Check location requirements
    if jurisdiction_requirement.present?
      return false unless festival.venue&.address&.include?(jurisdiction_requirement)
    end

    # Check attendance requirements
    if min_expected_attendance && festival.expected_attendance < min_expected_attendance
      return false
    end

    if max_expected_attendance && festival.expected_attendance > max_expected_attendance
      return false
    end

    true
  end

  # Calculates potential grant amount for a festival
  def calculate_grant_amount(festival_budget, requested_amount = nil)
    case grant_type
    when "percentage_based"
      calculated_amount = festival_budget * (grant_percentage || 0.0) / 100
    when "fixed_amount"
      calculated_amount = max_grant_amount
    when "matching_funds"
      calculated_amount = [ requested_amount || 0, max_grant_amount ].min
    when "reimbursement"
      calculated_amount = [ requested_amount || 0, max_grant_amount ].min
    else
      calculated_amount = [ requested_amount || 0, max_grant_amount ].min
    end

    # Apply constraints
    calculated_amount = [ calculated_amount, max_grant_amount ].min
    calculated_amount = [ calculated_amount, min_grant_amount ].max
    calculated_amount = [ calculated_amount, remaining_budget ].min

    calculated_amount.round(0)
  end

  # Returns application requirements as a formatted list
  def formatted_requirements
    requirements = application_requirements || {}

    formatted = []
    formatted << "事業計画書" if requirements["business_plan"]
    formatted << "予算書" if requirements["budget_plan"]
    formatted << "実施体制図" if requirements["organization_chart"]
    formatted << "会場使用許可書" if requirements["venue_permit"]
    formatted << "保険証書" if requirements["insurance_certificate"]
    formatted << "過去実績資料" if requirements["past_performance"]
    formatted << requirements["other"].split(",") if requirements["other"].present?

    formatted.flatten.compact
  end

  # Returns evaluation criteria with weights
  def evaluation_criteria_with_weights
    criteria = evaluation_criteria || {}

    {
      '文化的価値': criteria["cultural_value"] || 20,
      '地域貢献': criteria["community_impact"] || 25,
      '実現可能性': criteria["feasibility"] || 20,
      '予算妥当性': criteria["budget_appropriateness"] || 15,
      '継続性': criteria["sustainability"] || 10,
      '革新性': criteria["innovation"] || 10
    }
  end

  # Returns application statistics
  def application_statistics
    apps = subsidy_applications

    {
      total_applications: apps.count,
      pending_applications: apps.pending.count,
      approved_applications: apps.approved.count,
      rejected_applications: apps.rejected.count,
      total_requested: apps.sum(:requested_amount),
      total_granted: apps.approved.sum(:granted_amount),
      average_grant: apps.approved.average(:granted_amount)&.round(0) || 0,
      success_rate: apps.count > 0 ? (apps.approved.count.to_f / apps.count * 100).round(1) : 0
    }
  end

  # Returns days remaining for applications
  def days_remaining_for_applications
    return 0 unless accepting_applications?

    (application_end_date - Date.current).to_i
  end

  # Checks if program is oversubscribed
  def oversubscribed?
    budget_utilization_percentage > 90
  end

  # Returns similar programs from other authorities
  def similar_programs
    SubsidyProgram.active
                  .where.not(id: id)
                  .joins(:municipal_authority)
                  .where(municipal_authorities: { prefecture: municipal_authority.prefecture })
                  .where("eligible_festival_types && ?", eligible_festival_types)
                  .limit(5)
  end

  # Generates program summary for display
  def summary
    {
      name: name,
      authority: municipal_authority.name,
      grant_range: "¥#{min_grant_amount.to_s(:delimited)} - ¥#{max_grant_amount.to_s(:delimited)}",
      budget_remaining: "¥#{remaining_budget.to_s(:delimited)}",
      application_period: "#{application_start_date} 〜 #{application_end_date}",
      status: status.humanize,
      eligible_types: eligible_festival_types.join(", "),
      success_rate: "#{application_statistics[:success_rate]}%"
    }
  end

  # Class methods
  class << self
    # Finds programs suitable for a specific festival
    def suitable_for_festival(festival)
      programs = accepting_applications

      # Filter by festival type
      if festival.category.present?
        programs = programs.for_festival_type(festival.category)
      end

      # Filter by location
      if festival.venue&.address.present?
        authority_ids = MunicipalAuthority.for_area(festival.venue.address).pluck(:id)
        programs = programs.where(municipal_authority_id: authority_ids)
      end

      programs.select { |program| program.eligible_for_festival?(festival) }
    end

    # Returns programs by category
    def by_priority_category(category)
      where(priority_category: category)
    end

    # Returns programs with available budget
    def with_available_budget(minimum_amount = 0)
      where("total_budget - COALESCE((SELECT SUM(granted_amount) FROM subsidy_applications WHERE subsidy_program_id = subsidy_programs.id AND status = ?), 0) >= ?", "approved", minimum_amount)
    end

    # Import programs from external data
    def import_from_government_data(data_source)
      SubsidyDataImportService.new(data_source).import_programs
    end

    # Returns aggregated statistics
    def overall_statistics(period: 1.year)
      programs = where(created_at: period.ago..Time.current)

      {
        total_programs: programs.count,
        active_programs: programs.active.count,
        total_budget: programs.sum(:total_budget),
        total_granted: programs.joins(:subsidy_applications).where(subsidy_applications: { status: "approved" }).sum("subsidy_applications.granted_amount"),
        festivals_supported: programs.joins(:festivals).distinct.count("festivals.id")
      }
    end
  end

  private

  def end_date_after_start_date
    return unless application_start_date && application_end_date

    if application_end_date < application_start_date
      errors.add(:application_end_date, "must be after start date")
    end
  end

  def grant_amounts_logical
    return unless min_grant_amount && max_grant_amount

    if min_grant_amount > max_grant_amount
      errors.add(:min_grant_amount, "cannot be greater than maximum grant amount")
    end
  end

  def total_budget_sufficient
    return unless total_budget && max_grant_amount

    if total_budget < max_grant_amount
      errors.add(:total_budget, "must be at least equal to maximum grant amount")
    end
  end

  def calculate_remaining_budget
    # This will be calculated dynamically, but we can cache it if needed
  end

  def notify_applicants_of_changes
    return unless status_changed? && [ "suspended", "closed" ].include?(status)

    # Notify pending applicants of status changes
    subsidy_applications.pending.find_each do |application|
      SubsidyApplicationMailer.program_status_changed(application).deliver_later
    end
  end
end
