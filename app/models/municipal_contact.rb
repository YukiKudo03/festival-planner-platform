# frozen_string_literal: true

# Municipal Contact model for managing authority contact information
# Handles contact details for different departments and permit types
class MunicipalContact < ApplicationRecord
  # Associations
  belongs_to :municipal_authority

  # Validations
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :contact_type, presence: true, inclusion: { in: CONTACT_TYPES }
  validates :department, presence: true

  # Enums
  enum contact_type: {
    general: "general",
    event_permits: "event_permits",
    fire_safety: "fire_safety",
    health_permits: "health_permits",
    police_coordination: "police_coordination",
    tourism_support: "tourism_support",
    environmental_review: "environmental_review",
    emergency_contact: "emergency_contact"
  }

  enum status: {
    active: "active",
    inactive: "inactive",
    on_leave: "on_leave"
  }

  # Constants
  CONTACT_TYPES = %w[
    general
    event_permits
    fire_safety
    health_permits
    police_coordination
    tourism_support
    environmental_review
    emergency_contact
  ].freeze

  DEPARTMENTS = {
    "general" => "総務課",
    "event_permits" => "イベント許可課",
    "fire_safety" => "消防署",
    "health_permits" => "保健所",
    "police_coordination" => "警察署",
    "tourism_support" => "観光課",
    "environmental_review" => "環境課",
    "emergency_contact" => "危機管理室"
  }.freeze

  # JSON attributes
  serialize :working_hours, Hash
  serialize :specializations, Array
  serialize :languages_spoken, Array

  # Scopes
  scope :by_contact_type, ->(type) { where(contact_type: type) }
  scope :by_department, ->(dept) { where(department: dept) }
  scope :active, -> { where(status: "active") }
  scope :emergency_contacts, -> { where(contact_type: "emergency_contact") }
  scope :for_permit_type, ->(permit_type) { where(contact_type: permit_type_to_contact_type(permit_type)) }

  # Callbacks
  before_validation :normalize_contact_info
  after_create :send_welcome_notification
  after_update :sync_authority_contact, if: :saved_change_to_email?

  # Instance methods

  # Returns full name with title
  def full_name_with_title
    [ title, name ].compact.join(" ")
  end

  # Returns formatted contact information
  def formatted_contact_info
    {
      name: full_name_with_title,
      department: department_name,
      email: email,
      phone: formatted_phone,
      authority: municipal_authority.name
    }
  end

  # Returns department name in Japanese
  def department_name
    DEPARTMENTS[contact_type] || department
  end

  # Returns formatted phone number
  def formatted_phone
    return phone unless phone.match?(/\A\d+\z/)

    # Format Japanese phone numbers
    if phone.length == 10
      phone.gsub(/(\d{3})(\d{3})(\d{4})/, '\1-\2-\3')
    elsif phone.length == 11
      phone.gsub(/(\d{3})(\d{4})(\d{4})/, '\1-\2-\3')
    else
      phone
    end
  end

  # Returns working hours for today
  def todays_working_hours
    return nil unless working_hours.present?

    day_of_week = Date.current.strftime("%A").downcase
    working_hours[day_of_week] || working_hours["default"] || "9:00-17:00"
  end

  # Checks if currently available based on working hours
  def currently_available?
    return false unless active?

    hours = todays_working_hours
    return false if hours == "Closed" || hours.blank?

    begin
      now = Time.current.in_time_zone("Asia/Tokyo")
      start_time, end_time = hours.split("-")
      start_hour, start_min = start_time.split(":").map(&:to_i)
      end_hour, end_min = end_time.split(":").map(&:to_i)

      start_time_today = now.beginning_of_day + start_hour.hours + start_min.minutes
      end_time_today = now.beginning_of_day + end_hour.hours + end_min.minutes

      now.between?(start_time_today, end_time_today)
    rescue
      false
    end
  end

  # Returns specialization areas
  def specialization_list
    (specializations || []).join(", ")
  end

  # Returns spoken languages
  def language_list
    (languages_spoken || [ "日本語" ]).join(", ")
  end

  # Checks if contact speaks a specific language
  def speaks_language?(language)
    (languages_spoken || []).include?(language)
  end

  # Returns response time expectation
  def expected_response_time
    case contact_type
    when "emergency_contact"
      "Immediate"
    when "general", "event_permits"
      "24 hours"
    when "fire_safety", "health_permits"
      "48 hours"
    else
      "3-5 business days"
    end
  end

  # Sends notification to contact
  def send_notification(subject, message, urgent: false)
    MunicipalContactMailer.notification(self, subject, message, urgent: urgent).deliver_later
  end

  # Returns contact availability status
  def availability_status
    return "Inactive" unless active?
    return "On Leave" if on_leave?
    return "Available" if currently_available?

    "Outside Working Hours"
  end

  # Returns contact summary for API
  def api_summary
    {
      id: id,
      name: full_name_with_title,
      department: department_name,
      contact_type: contact_type.humanize,
      email: email,
      phone: formatted_phone,
      availability: availability_status,
      expected_response_time: expected_response_time,
      languages: language_list,
      specializations: specialization_list
    }
  end

  # Class methods
  class << self
    # Finds appropriate contact for permit type
    def for_permit_type(permit_type)
      contact_type = permit_type_to_contact_type(permit_type)
      by_contact_type(contact_type).active.first ||
        by_contact_type("general").active.first
    end

    # Finds emergency contacts
    def emergency_contacts_for_authority(authority)
      where(municipal_authority: authority, contact_type: "emergency_contact", status: "active")
    end

    # Returns contacts by availability
    def currently_available
      active.select(&:currently_available?)
    end

    # Maps permit types to contact types
    def permit_type_to_contact_type(permit_type)
      case permit_type
      when "event_permit", "road_use_permit", "noise_permit"
        "event_permits"
      when "fire_safety_inspection", "emergency_access_approval"
        "fire_safety"
      when "food_safety_permit", "sanitation_plan_approval"
        "health_permits"
      when "security_plan_approval", "traffic_control_permit"
        "police_coordination"
      when "environmental_impact_permit"
        "environmental_review"
      else
        "general"
      end
    end

    # Import contacts from external data
    def import_from_authority_data(authority, contact_data)
      contact_data.each do |data|
        find_or_create_by(
          municipal_authority: authority,
          email: data[:email]
        ) do |contact|
          contact.assign_attributes(data.except(:email))
        end
      end
    end

    # Returns contact statistics
    def statistics_for_authority(authority)
      contacts = where(municipal_authority: authority)

      {
        total_contacts: contacts.count,
        active_contacts: contacts.active.count,
        emergency_contacts: contacts.emergency_contacts.count,
        departments_covered: contacts.distinct.count(:department),
        currently_available: contacts.select(&:currently_available?).count
      }
    end
  end

  private

  def normalize_contact_info
    self.phone = phone&.gsub(/[^\d\-\(\)\+\s]/, "")
    self.email = email&.downcase&.strip
    self.name = name&.strip
  end

  def send_welcome_notification
    MunicipalContactMailer.welcome(self).deliver_later
  end

  def sync_authority_contact
    # Update authority's main contact if this is the general contact
    if general? && municipal_authority.contact_email != email
      municipal_authority.update(contact_email: email)
    end
  end
end
