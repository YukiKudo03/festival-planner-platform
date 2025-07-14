# frozen_string_literal: true

# Industry Specialization model for industry-specific festival versions
# Handles specialized configurations for different industry sectors
class IndustrySpecialization < ApplicationRecord
  # Associations
  belongs_to :festival
  has_many :industry_requirements, dependent: :destroy
  has_many :specialized_vendors, dependent: :destroy
  has_many :industry_certifications, dependent: :destroy
  has_many :industry_metrics, dependent: :destroy

  # Validations
  validates :industry_type, presence: true, inclusion: { in: INDUSTRY_TYPES }
  validates :specialization_level, presence: true, inclusion: { in: SPECIALIZATION_LEVELS }
  validates :certification_required, inclusion: { in: [ true, false ] }
  validates :compliance_standards, presence: true

  # Enums
  enum industry_type: {
    technology: "technology",
    healthcare: "healthcare",
    education: "education",
    manufacturing: "manufacturing",
    agriculture: "agriculture",
    finance: "finance",
    tourism_hospitality: "tourism_hospitality",
    retail: "retail",
    construction: "construction",
    automotive: "automotive",
    food_beverage: "food_beverage",
    entertainment: "entertainment",
    logistics: "logistics",
    energy: "energy",
    telecommunications: "telecommunications"
  }

  enum specialization_level: {
    basic: "basic",
    intermediate: "intermediate",
    advanced: "advanced",
    expert: "expert"
  }

  enum status: {
    planning: "planning",
    configuring: "configuring",
    active: "active",
    completed: "completed",
    archived: "archived"
  }

  # Constants
  INDUSTRY_TYPES = %w[
    technology
    healthcare
    education
    manufacturing
    agriculture
    finance
    tourism_hospitality
    retail
    construction
    automotive
    food_beverage
    entertainment
    logistics
    energy
    telecommunications
  ].freeze

  SPECIALIZATION_LEVELS = %w[basic intermediate advanced expert].freeze

  INDUSTRY_NAMES = {
    "technology" => "テクノロジー",
    "healthcare" => "ヘルスケア",
    "education" => "教育",
    "manufacturing" => "製造業",
    "agriculture" => "農業",
    "finance" => "金融",
    "tourism_hospitality" => "観光・ホスピタリティ",
    "retail" => "小売業",
    "construction" => "建設業",
    "automotive" => "自動車業",
    "food_beverage" => "飲食業",
    "entertainment" => "エンターテインメント",
    "logistics" => "物流",
    "energy" => "エネルギー",
    "telecommunications" => "通信"
  }.freeze

  # JSON attributes
  serialize :compliance_standards, Array
  serialize :specialized_features, Hash
  serialize :industry_regulations, Hash
  serialize :certification_requirements, Array
  serialize :performance_kpis, Hash
  serialize :vendor_criteria, Hash

  # Scopes
  scope :by_industry, ->(industry) { where(industry_type: industry) }
  scope :by_level, ->(level) { where(specialization_level: level) }
  scope :active, -> { where(status: "active") }
  scope :requiring_certification, -> { where(certification_required: true) }
  scope :advanced_level, -> { where(specialization_level: [ "advanced", "expert" ]) }

  # Callbacks
  before_create :set_specialization_code
  after_create :initialize_industry_features
  after_update :update_festival_configuration, if: :saved_change_to_specialized_features?

  # Instance methods

  # Returns human-readable industry name
  def industry_name
    INDUSTRY_NAMES[industry_type] || industry_type.humanize
  end

  # Returns specialization progress percentage
  def specialization_progress
    total_requirements = industry_requirements.count
    completed_requirements = industry_requirements.where(status: "completed").count

    return 0 if total_requirements.zero?

    (completed_requirements.to_f / total_requirements * 100).round(1)
  end

  # Returns required certifications
  def required_certifications_list
    certification_requirements || []
  end

  # Checks if all certifications are obtained
  def all_certifications_obtained?
    return true unless certification_required

    required_certs = required_certifications_list
    obtained_certs = industry_certifications.valid.pluck(:certification_type)

    (required_certs - obtained_certs).empty?
  end

  # Returns missing certifications
  def missing_certifications
    return [] unless certification_required

    required_certifications_list - industry_certifications.valid.pluck(:certification_type)
  end

  # Activates the specialization
  def activate!
    return false unless configuring?
    return false unless meets_activation_requirements?

    update!(
      status: "active",
      activated_at: Time.current
    )

    # Apply specialized configurations to festival
    apply_industry_configurations

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Completes the specialization
  def complete!(completion_notes: nil)
    return false unless active?

    update!(
      status: "completed",
      completed_at: Time.current,
      completion_notes: completion_notes
    )

    # Generate industry-specific report
    generate_industry_report

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  # Returns industry-specific vendor requirements
  def vendor_requirements
    base_requirements = vendor_criteria || {}

    case industry_type
    when "technology"
      base_requirements.merge({
        "tech_certifications" => [ "ISO 27001", "SOC 2" ],
        "experience_years" => 3,
        "portfolio_requirements" => "minimum 5 tech events"
      })
    when "healthcare"
      base_requirements.merge({
        "health_certifications" => [ "HIPAA", "FDA compliance" ],
        "insurance_requirements" => "medical liability coverage",
        "background_checks" => "required for all staff"
      })
    when "finance"
      base_requirements.merge({
        "financial_certifications" => [ "PCI DSS", "SOX compliance" ],
        "security_clearance" => "required",
        "audit_trail" => "complete transaction logging"
      })
    else
      base_requirements
    end
  end

  # Returns industry-specific KPIs
  def industry_kpis
    base_kpis = performance_kpis || {}

    case industry_type
    when "technology"
      base_kpis.merge({
        "innovation_index" => 0,
        "tech_adoption_rate" => 0,
        "digital_engagement" => 0,
        "startup_participation" => 0
      })
    when "healthcare"
      base_kpis.merge({
        "patient_safety_score" => 0,
        "medical_education_hours" => 0,
        "health_screenings_conducted" => 0,
        "research_presentations" => 0
      })
    when "manufacturing"
      base_kpis.merge({
        "production_efficiency" => 0,
        "quality_standards_met" => 0,
        "automation_showcase" => 0,
        "supply_chain_innovations" => 0
      })
    else
      base_kpis
    end
  end

  # Returns compliance checklist
  def compliance_checklist
    standards = compliance_standards || []
    regulations = industry_regulations || {}

    checklist = []

    standards.each do |standard|
      checklist << {
        category: "Standards",
        requirement: standard,
        status: check_compliance_status(standard),
        mandatory: true
      }
    end

    regulations.each do |regulation, details|
      checklist << {
        category: "Regulations",
        requirement: regulation,
        details: details,
        status: check_regulation_compliance(regulation),
        mandatory: details["mandatory"] || false
      }
    end

    checklist
  end

  # Updates industry metrics
  def update_metrics(metrics_data)
    current_kpis = industry_kpis

    metrics_data.each do |metric, value|
      if current_kpis.key?(metric)
        industry_metrics.create!(
          metric_name: metric,
          metric_value: value,
          recorded_at: Time.current
        )

        current_kpis[metric] = value
      end
    end

    update!(performance_kpis: current_kpis)
  end

  # Returns specialization summary
  def summary
    {
      specialization_code: specialization_code,
      industry_type: industry_name,
      specialization_level: specialization_level.humanize,
      status: status.humanize,
      festival_name: festival.name,
      progress_percentage: specialization_progress,
      certification_required: certification_required,
      certifications_obtained: all_certifications_obtained?,
      missing_certifications: missing_certifications,
      compliance_score: calculate_compliance_score,
      activated_at: activated_at,
      completed_at: completed_at
    }
  end

  # Class methods
  class << self
    # Returns specializations by industry
    def by_industry_type(industry)
      by_industry(industry)
    end

    # Returns industry statistics
    def industry_statistics
      stats = {
        total_specializations: count,
        by_industry: group(:industry_type).count,
        by_level: group(:specialization_level).count,
        by_status: group(:status).count,
        certification_adoption: where(certification_required: true).count,
        average_progress: average("specialization_progress") || 0
      }

      stats[:industry_distribution] = stats[:by_industry].transform_keys { |k| INDUSTRY_NAMES[k] || k }
      stats
    end

    # Returns top performing industries
    def top_performing_industries(limit: 5)
      joins(:industry_metrics)
        .group(:industry_type)
        .order("AVG(industry_metrics.metric_value) DESC")
        .limit(limit)
        .pluck(:industry_type)
    end

    # Creates industry template
    def create_industry_template(industry_type, level = "basic")
      template = {
        industry_type: industry_type,
        specialization_level: level,
        compliance_standards: get_industry_standards(industry_type),
        specialized_features: get_industry_features(industry_type),
        certification_requirements: get_certification_requirements(industry_type),
        industry_regulations: get_industry_regulations(industry_type)
      }

      template
    end

    private

    def get_industry_standards(industry)
      case industry
      when "technology"
        [ "ISO 27001", "GDPR compliance", "Accessibility standards" ]
      when "healthcare"
        [ "HIPAA", "FDA regulations", "Medical device standards" ]
      when "finance"
        [ "PCI DSS", "SOX compliance", "KYC/AML standards" ]
      when "manufacturing"
        [ "ISO 9001", "ISO 14001", "Safety standards" ]
      else
        [ "Basic safety standards", "Data protection" ]
      end
    end

    def get_industry_features(industry)
      case industry
      when "technology"
        {
          "demo_stations" => true,
          "networking_sessions" => true,
          "innovation_showcases" => true,
          "tech_talks" => true
        }
      when "healthcare"
        {
          "medical_presentations" => true,
          "health_screenings" => true,
          "research_posters" => true,
          "continuing_education" => true
        }
      else
        {}
      end
    end

    def get_certification_requirements(industry)
      case industry
      when "technology"
        [ "Technical certification", "Security clearance" ]
      when "healthcare"
        [ "Medical license", "Continuing education credits" ]
      when "finance"
        [ "Financial industry certification", "Compliance training" ]
      else
        []
      end
    end

    def get_industry_regulations(industry)
      case industry
      when "technology"
        {
          "data_protection" => { "mandatory" => true, "description" => "GDPR compliance required" },
          "cybersecurity" => { "mandatory" => true, "description" => "Security protocols mandatory" }
        }
      when "healthcare"
        {
          "patient_privacy" => { "mandatory" => true, "description" => "HIPAA compliance required" },
          "medical_safety" => { "mandatory" => true, "description" => "Medical safety protocols" }
        }
      else
        {}
      end
    end
  end

  private

  def set_specialization_code
    year = Date.current.year
    sequence = IndustrySpecialization.where("created_at >= ?", Date.current.beginning_of_year).count + 1
    industry_code = industry_type.first(3).upcase
    level_code = specialization_level.first(1).upcase

    self.specialization_code = "IS#{year}#{industry_code}#{level_code}#{sequence.to_s.rjust(3, '0')}"
  end

  def initialize_industry_features
    # Set default specialized features based on industry
    default_features = self.class.send(:get_industry_features, industry_type)
    self.update!(specialized_features: default_features) if default_features.any?

    # Create initial requirements
    create_initial_requirements
  end

  def create_initial_requirements
    compliance_standards.each do |standard|
      industry_requirements.create!(
        requirement_type: "compliance",
        title: standard,
        description: "Implement #{standard} compliance",
        mandatory: true,
        status: "pending"
      )
    end
  end

  def meets_activation_requirements?
    # Check if all mandatory requirements are met
    mandatory_requirements = industry_requirements.where(mandatory: true)
    incomplete_requirements = mandatory_requirements.where.not(status: "completed")

    return false if incomplete_requirements.any?

    # Check certifications if required
    return false if certification_required && !all_certifications_obtained?

    true
  end

  def apply_industry_configurations
    # Apply specialized features to festival
    festival.update!(industry_specific_config: specialized_features)

    # Configure industry-specific vendor categories
    configure_vendor_categories

    # Set up industry KPIs tracking
    initialize_kpi_tracking
  end

  def configure_vendor_categories
    # Add industry-specific vendor categories based on industry type
    case industry_type
    when "technology"
      festival.vendor_categories.find_or_create_by(name: "Software Demos")
      festival.vendor_categories.find_or_create_by(name: "Hardware Exhibitions")
      festival.vendor_categories.find_or_create_by(name: "Startup Showcases")
    when "healthcare"
      festival.vendor_categories.find_or_create_by(name: "Medical Devices")
      festival.vendor_categories.find_or_create_by(name: "Health Services")
      festival.vendor_categories.find_or_create_by(name: "Research Institutions")
    end
  end

  def initialize_kpi_tracking
    kpis = industry_kpis
    self.update!(performance_kpis: kpis)

    # Create baseline metrics
    kpis.each do |metric, value|
      industry_metrics.create!(
        metric_name: metric,
        metric_value: value,
        recorded_at: Time.current,
        is_baseline: true
      )
    end
  end

  def check_compliance_status(standard)
    # Check if compliance requirement is met
    requirement = industry_requirements.find_by(title: standard)
    requirement&.status || "pending"
  end

  def check_regulation_compliance(regulation)
    # Check regulation compliance based on festival configuration
    case regulation
    when "data_protection"
      festival.privacy_policy_url.present? ? "compliant" : "pending"
    when "cybersecurity"
      festival.security_measures.present? ? "compliant" : "pending"
    else
      "pending"
    end
  end

  def calculate_compliance_score
    checklist = compliance_checklist
    return 0 if checklist.empty?

    compliant_items = checklist.count { |item| item[:status] == "compliant" || item[:status] == "completed" }

    (compliant_items.to_f / checklist.length * 100).round(1)
  end

  def update_festival_configuration
    # Update festival with new specialized features
    festival.update!(industry_specific_config: specialized_features)
  end

  def generate_industry_report
    IndustryReportGeneratorJob.perform_later(self)
  end
end
