class CalendarIntegration < ApplicationRecord
  belongs_to :user
  belongs_to :festival, optional: true

  validates :provider, presence: true, inclusion: { in: %w[google outlook ical] }
  validates :name, presence: true
  validates :calendar_id, presence: true

  encrypts :access_token
  encrypts :refresh_token
  encrypts :client_secret

  scope :active, -> { where(active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }

  enum sync_direction: {
    one_way_to_calendar: 0,    # Festival events → Calendar
    one_way_from_calendar: 1,  # Calendar → Festival events
    bidirectional: 2           # Both directions
  }

  enum status: {
    connected: 0,
    disconnected: 1,
    error: 2,
    expired: 3
  }

  before_create :set_defaults
  after_update :schedule_sync, if: :saved_change_to_active?

  def google_calendar?
    provider == "google"
  end

  def outlook_calendar?
    provider == "outlook"
  end

  def ical_calendar?
    provider == "ical"
  end

  def sync_enabled?
    active? && connected? && access_token.present?
  end

  def last_sync_status
    last_sync_error.present? ? "error" : "success"
  end

  def sync_overdue?
    return false unless sync_enabled?
    return true if last_synced_at.nil?

    last_synced_at < sync_interval.hours.ago
  end

  def token_expired?
    return false unless expires_at.present?
    expires_at < Time.current
  end

  def refresh_access_token!
    case provider
    when "google"
      refresh_google_token!
    when "outlook"
      refresh_outlook_token!
    else
      false
    end
  end

  def calendar_service
    @calendar_service ||= case provider
    when "google"
                           GoogleCalendarService.new(self)
    when "outlook"
                           OutlookCalendarService.new(self)
    when "ical"
                           IcalCalendarService.new(self)
    end
  end

  def sync_events!
    return false unless sync_enabled?

    begin
      case sync_direction
      when "one_way_to_calendar"
        sync_to_calendar
      when "one_way_from_calendar"
        sync_from_calendar
      when "bidirectional"
        sync_bidirectional
      end

      update!(
        last_synced_at: Time.current,
        last_sync_error: nil,
        status: :connected
      )

      true
    rescue => error
      update!(
        last_sync_error: error.message,
        status: :error
      )

      Rails.logger.error "Calendar sync failed for #{id}: #{error.message}"
      false
    end
  end

  def export_festival_events
    return [] unless festival.present?

    events = []

    # Festival main event
    if festival.start_date && festival.end_date
      events << {
        summary: festival.name,
        description: festival.description,
        start_date: festival.start_date,
        end_date: festival.end_date,
        location: festival.location,
        event_type: "festival"
      }
    end

    # Tasks with deadlines
    festival.tasks.where.not(due_date: nil).find_each do |task|
      events << {
        summary: "Task: #{task.title}",
        description: task.description,
        start_date: task.due_date,
        end_date: task.due_date,
        location: festival.location,
        event_type: "task_deadline",
        task_id: task.id,
        priority: task.priority
      }
    end

    events
  end

  def create_ical_feed
    calendar = Icalendar::Calendar.new

    export_festival_events.each do |event_data|
      event = Icalendar::Event.new

      event.dtstart = Icalendar::Values::Date.new(event_data[:start_date])
      event.dtend = Icalendar::Values::Date.new(event_data[:end_date])
      event.summary = event_data[:summary]
      event.description = event_data[:description]
      event.location = event_data[:location] if event_data[:location]
      event.uid = "#{event_data[:event_type]}-#{id}-#{event_data[:task_id] || festival.id}@festival-planner.com"
      event.created = Icalendar::Values::DateTime.new(Time.current)
      event.last_modified = Icalendar::Values::DateTime.new(Time.current)

      # Add custom properties
      event.append_custom_property("X-FESTIVAL-ID", festival.id.to_s) if festival
      event.append_custom_property("X-EVENT-TYPE", event_data[:event_type])
      event.append_custom_property("X-PRIORITY", event_data[:priority]) if event_data[:priority]

      calendar.add_event(event)
    end

    calendar.to_ical
  end

  private

  def set_defaults
    self.sync_interval ||= 24 # Default: sync every 24 hours
    self.active ||= true
    self.status ||= :connected
    self.sync_direction ||= :one_way_to_calendar
  end

  def schedule_sync
    return unless active?

    CalendarSyncJob.perform_later(id)
  end

  def sync_to_calendar
    events = export_festival_events
    calendar_service.create_events(events)
  end

  def sync_from_calendar
    calendar_events = calendar_service.fetch_events
    import_calendar_events(calendar_events)
  end

  def sync_bidirectional
    # Export festival events to calendar
    sync_to_calendar

    # Import calendar events (excluding our own events)
    calendar_events = calendar_service.fetch_events(exclude_festival_events: true)
    import_calendar_events(calendar_events)
  end

  def import_calendar_events(calendar_events)
    return unless festival.present?

    calendar_events.each do |cal_event|
      # Skip if we already have this event
      next if festival.tasks.where(
        calendar_event_id: cal_event[:id],
        calendar_integration_id: id
      ).exists?

      # Create task from calendar event
      task = festival.tasks.build(
        title: cal_event[:summary],
        description: cal_event[:description],
        due_date: cal_event[:start_date],
        status: "pending",
        priority: "medium",
        calendar_event_id: cal_event[:id],
        calendar_integration_id: id,
        created_by: user
      )

      task.save!
    end
  end

  def refresh_google_token!
    return false unless google_calendar? && refresh_token.present?

    auth_client = Google::Auth::UserRefreshCredentials.new(
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token,
      scope: [ "https://www.googleapis.com/auth/calendar" ]
    )

    auth_client.refresh!

    update!(
      access_token: auth_client.access_token,
      expires_at: Time.current + auth_client.expires_in.seconds,
      status: :connected
    )

    true
  rescue => error
    update!(status: :expired, last_sync_error: error.message)
    false
  end

  def refresh_outlook_token!
    return false unless outlook_calendar? && refresh_token.present?

    oauth_client = OAuth2::Client.new(
      client_id,
      client_secret,
      site: "https://login.microsoftonline.com",
      token_url: "/common/oauth2/v2.0/token"
    )

    token = OAuth2::AccessToken.from_hash(
      oauth_client,
      refresh_token: refresh_token
    )

    new_token = token.refresh!

    update!(
      access_token: new_token.token,
      refresh_token: new_token.refresh_token,
      expires_at: Time.current + new_token.expires_in.seconds,
      status: :connected
    )

    true
  rescue => error
    update!(status: :expired, last_sync_error: error.message)
    false
  end
end
