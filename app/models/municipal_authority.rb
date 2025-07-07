# frozen_string_literal: true

# Municipal Authority model for government agency integration
# Represents local government organizations that regulate festivals
class MunicipalAuthority < ApplicationRecord
  # Associations
  has_many :permit_applications, dependent: :destroy
  has_many :subsidy_programs, dependent: :destroy
  has_many :municipal_contacts, dependent: :destroy
  has_many :festivals, through: :permit_applications
  has_many :safety_compliance_records, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { scope: :prefecture }
  validates :prefecture, presence: true
  validates :city, presence: true
  validates :authority_type, presence: true, inclusion: { in: AUTHORITY_TYPES }
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone_number, presence: true
  validates :jurisdiction_area, presence: true

  # Enums
  enum authority_type: {
    city_hall: 'city_hall',
    prefecture_office: 'prefecture_office',
    police_department: 'police_department',
    fire_department: 'fire_department',
    health_department: 'health_department',
    tourism_board: 'tourism_board',
    environmental_agency: 'environmental_agency',
    labor_standards: 'labor_standards'
  }

  enum status: {
    active: 'active',
    inactive: 'inactive',
    suspended: 'suspended'
  }

  # Constants
  AUTHORITY_TYPES = %w[
    city_hall
    prefecture_office
    police_department
    fire_department
    health_department
    tourism_board
    environmental_agency
    labor_standards
  ].freeze

  PREFECTURES = %w[
    北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県
    茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
    新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県
    静岡県 愛知県 三重県 滋賀県 京都府 大阪府 兵庫県
    奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県
    徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県
    熊本県 大分県 宮崎県 鹿児島県 沖縄県
  ].freeze

  # Scopes
  scope :by_prefecture, ->(prefecture) { where(prefecture: prefecture) }
  scope :by_authority_type, ->(type) { where(authority_type: type) }
  scope :active, -> { where(status: 'active') }
  scope :in_jurisdiction, ->(area) { where('jurisdiction_area ILIKE ?', "%#{area}%") }

  # Callbacks
  before_validation :normalize_contact_info
  after_create :create_default_contacts
  after_update :sync_contact_changes, if: :saved_change_to_contact_email?

  # Instance methods

  # Returns full display name with authority type
  def full_name
    "#{name} (#{authority_type.humanize})"
  end

  # Returns formatted address
  def full_address
    [address, city, prefecture].compact.join(', ')
  end

  # Checks if this authority has jurisdiction over a given area
  def has_jurisdiction?(area_name)
    jurisdiction_area.downcase.include?(area_name.downcase) ||
      city.downcase.include?(area_name.downcase) ||
      prefecture.downcase.include?(area_name.downcase)
  end

  # Returns required permits for a given festival type
  def required_permits_for(festival_type, estimated_attendance)
    permits = []
    
    case authority_type
    when 'city_hall'
      permits << 'event_permit' if estimated_attendance > 100
      permits << 'road_use_permit' if festival_type.include?('outdoor')
      permits << 'noise_permit' if festival_type.include?('music')
    when 'police_department'
      permits << 'security_plan_approval' if estimated_attendance > 500
      permits << 'traffic_control_permit' if estimated_attendance > 1000
    when 'fire_department'
      permits << 'fire_safety_inspection' if estimated_attendance > 300
      permits << 'emergency_access_approval'
    when 'health_department'
      permits << 'food_safety_permit' if festival_type.include?('food')
      permits << 'sanitation_plan_approval' if estimated_attendance > 200
    end
    
    permits
  end

  # Returns processing time for permit applications
  def typical_processing_time(permit_type)
    case permit_type
    when 'event_permit'
      business_days: 14
    when 'security_plan_approval'
      business_days: 21
    when 'fire_safety_inspection'
      business_days: 10
    when 'food_safety_permit'
      business_days: 7
    else
      business_days: 14
    end
  end

  # Returns contact information for specific permit types
  def contact_for_permit(permit_type)
    municipal_contacts.find_by(permit_type: permit_type) ||
      municipal_contacts.find_by(contact_type: 'general') ||
      default_contact
  end

  # Returns available subsidy programs
  def available_subsidies(festival_type: nil, estimated_budget: nil)
    programs = subsidy_programs.active
    programs = programs.where('eligible_festival_types @> ?', [festival_type].to_json) if festival_type
    programs = programs.where('min_budget <= ? AND max_budget >= ?', estimated_budget, estimated_budget) if estimated_budget
    programs
  end

  # Checks if API integration is available
  def api_integration_available?
    api_endpoint.present? && api_key.present?
  end

  # Returns integration status
  def integration_status
    return 'not_configured' unless api_integration_available?
    return 'active' if last_api_sync_at && last_api_sync_at > 24.hours.ago
    return 'stale' if last_api_sync_at && last_api_sync_at > 7.days.ago
    'inactive'
  end

  # Syncs data with municipal API
  def sync_with_api
    return false unless api_integration_available?

    begin
      MunicipalApiSyncService.new(self).perform_sync
      update(last_api_sync_at: Time.current, api_sync_status: 'success')
      true
    rescue StandardError => e
      Rails.logger.error "Municipal API sync failed for #{name}: #{e.message}"
      update(api_sync_status: 'failed', api_sync_error: e.message)
      false
    end
  end

  # Returns statistics for this authority
  def statistics
    {
      total_permit_applications: permit_applications.count,
      approved_applications: permit_applications.approved.count,
      pending_applications: permit_applications.pending.count,
      avg_processing_days: average_processing_days,
      total_subsidies_granted: subsidy_programs.sum(:total_budget),
      festivals_supported: festivals.distinct.count
    }
  end

  # Returns working hours information
  def working_hours
    {
      monday: working_hours_monday || '9:00-17:00',
      tuesday: working_hours_tuesday || '9:00-17:00',
      wednesday: working_hours_wednesday || '9:00-17:00',
      thursday: working_hours_thursday || '9:00-17:00',
      friday: working_hours_friday || '9:00-17:00',
      saturday: working_hours_saturday || 'Closed',
      sunday: working_hours_sunday || 'Closed'
    }
  end

  # Returns if currently open based on working hours
  def currently_open?
    now = Time.current.in_time_zone('Asia/Tokyo')
    day_of_week = now.strftime('%A').downcase
    hours = working_hours[day_of_week.to_sym]
    
    return false if hours == 'Closed' || hours.blank?
    
    begin
      start_time, end_time = hours.split('-')
      start_hour, start_min = start_time.split(':').map(&:to_i)
      end_hour, end_min = end_time.split(':').map(&:to_i)
      
      start_time_today = now.beginning_of_day + start_hour.hours + start_min.minutes
      end_time_today = now.beginning_of_day + end_hour.hours + end_min.minutes
      
      now.between?(start_time_today, end_time_today)
    rescue
      false
    end
  end

  # Class methods
  class << self
    # Finds authorities with jurisdiction over a specific area
    def for_area(area_name)
      where('jurisdiction_area ILIKE ? OR city ILIKE ?', "%#{area_name}%", "%#{area_name}%")
    end

    # Returns authorities by prefecture
    def in_prefecture(prefecture)
      where(prefecture: prefecture)
    end

    # Finds authorities that handle specific permit types
    def handling_permit_type(permit_type)
      case permit_type
      when 'event_permit', 'road_use_permit'
        where(authority_type: ['city_hall', 'prefecture_office'])
      when 'security_plan_approval', 'traffic_control_permit'
        where(authority_type: 'police_department')
      when 'fire_safety_inspection', 'emergency_access_approval'
        where(authority_type: 'fire_department')
      when 'food_safety_permit', 'sanitation_plan_approval'
        where(authority_type: 'health_department')
      else
        all
      end
    end

    # Returns authorities offering subsidies
    def with_subsidies
      joins(:subsidy_programs).where(subsidy_programs: { status: 'active' }).distinct
    end

    # Import authorities from external data source
    def import_from_data(data_source)
      MunicipalDataImportService.new(data_source).import_authorities
    end
  end

  private

  def normalize_contact_info
    self.phone_number = phone_number&.gsub(/[^\d\-\(\)\+\s]/, '')
    self.contact_email = contact_email&.downcase&.strip
  end

  def create_default_contacts
    municipal_contacts.create!(
      contact_type: 'general',
      name: "#{name} General Contact",
      email: contact_email,
      phone: phone_number,
      department: 'General Affairs'
    )
  end

  def sync_contact_changes
    municipal_contacts.where(contact_type: 'general').update_all(email: contact_email)
  end

  def default_contact
    OpenStruct.new(
      name: "#{name} General Contact",
      email: contact_email,
      phone: phone_number,
      department: 'General Affairs'
    )
  end

  def average_processing_days
    completed_applications = permit_applications.where.not(approved_at: nil, created_at: nil)
    return 0 if completed_applications.empty?

    total_days = completed_applications.sum do |app|
      (app.approved_at.to_date - app.created_at.to_date).to_i
    end

    (total_days.to_f / completed_applications.count).round(1)
  end
end