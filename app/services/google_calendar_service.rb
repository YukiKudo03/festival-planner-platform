require "google/apis/calendar_v3"
require "google/auth"

class GoogleCalendarService
  include Rails.application.routes.url_helpers

  def initialize(calendar_integration)
    @integration = calendar_integration
    @service = Google::Apis::CalendarV3::CalendarService.new
    setup_authorization
  end

  def test_connection
    begin
      @service.get_calendar("primary")
      { success: true, message: "Google Calendar connection successful" }
    rescue => error
      { success: false, message: error.message }
    end
  end

  def fetch_calendars
    begin
      calendar_list = @service.list_calendar_lists

      calendars = calendar_list.items.map do |calendar|
        {
          id: calendar.id,
          name: calendar.summary,
          description: calendar.description,
          primary: calendar.primary || false,
          access_role: calendar.access_role,
          color: calendar.background_color
        }
      end

      { success: true, calendars: calendars }
    rescue => error
      { success: false, message: error.message }
    end
  end

  def create_events(events)
    created_events = []

    events.each do |event_data|
      begin
        google_event = build_google_event(event_data)
        created_event = @service.insert_event(@integration.calendar_id, google_event)

        created_events << {
          id: created_event.id,
          html_link: created_event.html_link,
          festival_event_type: event_data[:event_type],
          task_id: event_data[:task_id]
        }

        # Update task with calendar event ID if applicable
        if event_data[:task_id].present?
          task = Task.find_by(id: event_data[:task_id])
          task&.update(google_event_id: created_event.id)
        end

      rescue => error
        Rails.logger.error "Failed to create Google Calendar event: #{error.message}"
        Rails.logger.error "Event data: #{event_data}"
      end
    end

    created_events
  end

  def update_event(event_id, event_data)
    begin
      google_event = build_google_event(event_data)
      updated_event = @service.update_event(@integration.calendar_id, event_id, google_event)

      {
        success: true,
        event: {
          id: updated_event.id,
          html_link: updated_event.html_link
        }
      }
    rescue => error
      {
        success: false,
        message: error.message
      }
    end
  end

  def delete_event(event_id)
    begin
      @service.delete_event(@integration.calendar_id, event_id)
      { success: true }
    rescue => error
      { success: false, message: error.message }
    end
  end

  def fetch_events(options = {})
    begin
      time_min = (options[:start_date] || 1.month.ago).beginning_of_day.rfc3339
      time_max = (options[:end_date] || 3.months.from_now).end_of_day.rfc3339

      events = @service.list_events(
        @integration.calendar_id,
        time_min: time_min,
        time_max: time_max,
        single_events: true,
        order_by: "startTime"
      )

      calendar_events = events.items.map do |event|
        # Skip our own festival events if requested
        if options[:exclude_festival_events] &&
           event.description&.include?("Festival Planner Platform")
          next
        end

        {
          id: event.id,
          summary: event.summary,
          description: event.description,
          start_date: parse_event_datetime(event.start),
          end_date: parse_event_datetime(event.end),
          location: event.location,
          html_link: event.html_link,
          attendees: event.attendees&.map { |a| a.email } || [],
          created: event.created,
          updated: event.updated
        }
      end.compact

      { success: true, events: calendar_events }
    rescue => error
      { success: false, message: error.message }
    end
  end

  def create_festival_calendar(festival)
    begin
      calendar = Google::Apis::CalendarV3::Calendar.new(
        summary: "#{festival.name} - Festival Planning",
        description: "Calendar for #{festival.name} planning and events. Managed by Festival Planner Platform.",
        time_zone: festival.timezone || "Asia/Tokyo"
      )

      created_calendar = @service.insert_calendar(calendar)

      # Set calendar permissions (make it shared with festival members)
      festival.users.each do |user|
        next unless user.email.present?

        acl_rule = Google::Apis::CalendarV3::AclRule.new(
          role: "reader", # or 'writer' for more permissions
          scope: Google::Apis::CalendarV3::AclRule::Scope.new(
            type: "user",
            value: user.email
          )
        )

        begin
          @service.insert_acl(created_calendar.id, acl_rule)
        rescue => acl_error
          Rails.logger.warn "Failed to share calendar with #{user.email}: #{acl_error.message}"
        end
      end

      {
        success: true,
        calendar: {
          id: created_calendar.id,
          name: created_calendar.summary,
          html_link: "https://calendar.google.com/calendar/embed?src=#{created_calendar.id}"
        }
      }
    rescue => error
      { success: false, message: error.message }
    end
  end

  def sync_festival_events(festival)
    events_data = []

    # Main festival event
    if festival.start_date && festival.end_date
      events_data << {
        summary: "🎉 #{festival.name}",
        description: build_festival_description(festival),
        start_date: festival.start_date,
        end_date: festival.end_date,
        location: festival.location,
        event_type: "festival_main",
        color_id: "10" # Green color for festivals
      }
    end

    # Setup/preparation period
    if festival.start_date
      setup_start = festival.start_date - 7.days
      events_data << {
        summary: "🔧 #{festival.name} - Setup Period",
        description: "Preparation and setup period for #{festival.name}",
        start_date: setup_start,
        end_date: festival.start_date - 1.day,
        location: festival.location,
        event_type: "festival_setup",
        color_id: "5" # Yellow color for preparation
      }
    end

    # Task deadlines
    festival.tasks.where.not(due_date: nil).find_each do |task|
      events_data << {
        summary: "📋 Task: #{task.title}",
        description: build_task_description(task),
        start_date: task.due_date,
        end_date: task.due_date,
        location: festival.location,
        event_type: "task_deadline",
        task_id: task.id,
        color_id: priority_color_id(task.priority)
      }
    end

    # Budget milestones
    if festival.budget_categories.any?
      festival.budget_categories.includes(:expenses).each do |category|
        next unless category.expenses.any?

        # Find the latest expense date as milestone
        latest_expense = category.expenses.order(:created_at).last
        next unless latest_expense

        events_data << {
          summary: "💰 Budget: #{category.name}",
          description: "Budget category milestone: #{category.name}\nBudget: ¥#{category.budget_amount}\nSpent: ¥#{category.expenses.sum(:amount)}",
          start_date: latest_expense.created_at.to_date,
          end_date: latest_expense.created_at.to_date,
          event_type: "budget_milestone",
          color_id: "6" # Orange color for budget
        }
      end
    end

    create_events(events_data)
  end

  def create_recurring_reminders(festival)
    recurring_events = []

    return recurring_events unless festival.start_date

    # Weekly team meetings (if festival is more than 1 month away)
    if festival.start_date > 1.month.from_now
      meeting_start = 1.week.from_now.beginning_of_week + 10.hours # Monday 10:00

      recurring_events << {
        summary: "👥 #{festival.name} - Weekly Planning Meeting",
        description: "Weekly planning meeting for #{festival.name}",
        start_date: meeting_start,
        end_date: meeting_start + 1.hour,
        recurrence: [ "RRULE:FREQ=WEEKLY;UNTIL=" + (festival.start_date - 1.week).strftime("%Y%m%dT%H%M%SZ") ],
        event_type: "recurring_meeting",
        color_id: "11" # Red color for meetings
      }
    end

    # Milestone reminders
    milestones = [
      { days_before: 30, title: "1 Month Reminder" },
      { days_before: 14, title: "2 Weeks Reminder" },
      { days_before: 7, title: "Final Week Reminder" },
      { days_before: 1, title: "Final Day Preparation" }
    ]

    milestones.each do |milestone|
      reminder_date = festival.start_date - milestone[:days_before].days
      next if reminder_date < Date.current

      recurring_events << {
        summary: "⏰ #{festival.name} - #{milestone[:title]}",
        description: "#{milestone[:title]} for #{festival.name}. Time to finalize preparations!",
        start_date: reminder_date,
        end_date: reminder_date,
        event_type: "milestone_reminder",
        color_id: "8" # Gray color for reminders
      }
    end

    create_events(recurring_events)
  end

  private

  def setup_authorization
    if @integration.token_expired?
      @integration.refresh_access_token!
    end

    @service.authorization = Google::Auth::UserRefreshCredentials.new(
      client_id: @integration.client_id,
      client_secret: @integration.client_secret,
      refresh_token: @integration.refresh_token,
      access_token: @integration.access_token,
      scope: [ "https://www.googleapis.com/auth/calendar" ]
    )
  end

  def build_google_event(event_data)
    event = Google::Apis::CalendarV3::Event.new

    event.summary = event_data[:summary]
    event.description = event_data[:description]
    event.location = event_data[:location] if event_data[:location]

    # Set start and end times
    if event_data[:start_date].is_a?(Date)
      # All-day event
      event.start = Google::Apis::CalendarV3::EventDateTime.new(
        date: event_data[:start_date]
      )
      event.end = Google::Apis::CalendarV3::EventDateTime.new(
        date: event_data[:end_date] || event_data[:start_date]
      )
    else
      # Timed event
      event.start = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event_data[:start_date].rfc3339
      )
      event.end = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: (event_data[:end_date] || event_data[:start_date] + 1.hour).rfc3339
      )
    end

    # Set color
    event.color_id = event_data[:color_id] if event_data[:color_id]

    # Set recurrence if specified
    event.recurrence = event_data[:recurrence] if event_data[:recurrence]

    # Add reminders
    event.reminders = Google::Apis::CalendarV3::Event::Reminders.new(
      use_default: false,
      overrides: [
        Google::Apis::CalendarV3::EventReminder.new(method: "email", minutes: 24 * 60), # 1 day before
        Google::Apis::CalendarV3::EventReminder.new(method: "popup", minutes: 60)       # 1 hour before
      ]
    )

    # Add custom properties for identification
    event.extended_properties = Google::Apis::CalendarV3::Event::ExtendedProperties.new(
      private: {
        "festival_planner_event" => "true",
        "event_type" => event_data[:event_type],
        "festival_id" => @integration.festival_id.to_s,
        "task_id" => event_data[:task_id].to_s
      }.compact
    )

    event
  end

  def parse_event_datetime(datetime_obj)
    if datetime_obj.date
      Date.parse(datetime_obj.date)
    elsif datetime_obj.date_time
      Time.parse(datetime_obj.date_time)
    else
      nil
    end
  end

  def build_festival_description(festival)
    description = festival.description || ""
    description += "\n\n" unless description.empty?
    description += "📅 期間: #{festival.start_date&.strftime('%Y年%m月%d日')} - #{festival.end_date&.strftime('%Y年%m月%d日')}\n"
    description += "📍 場所: #{festival.location}\n" if festival.location
    description += "💰 予算: ¥#{festival.budget.to_i.to_s(:delimited)}\n" if festival.budget
    description += "👥 参加者数: #{festival.users.count}名\n"
    description += "\n🔗 Festival Planner Platform で管理\n"
    description += festival_url(festival) if defined?(festival_url)
    description
  end

  def build_task_description(task)
    description = task.description || ""
    description += "\n\n" unless description.empty?
    description += "⚠️ 優先度: #{task.priority}\n"
    description += "📊 ステータス: #{task.status}\n"
    description += "👤 担当者: #{task.assigned_user&.name}\n" if task.assigned_user
    description += "📅 期限: #{task.due_date&.strftime('%Y年%m月%d日')}\n"
    description += "📈 進捗: #{task.progress}%\n" if task.progress
    description += "\n🔗 Festival Planner Platform で管理"
    description
  end

  def priority_color_id(priority)
    case priority
    when "urgent"
      "11" # Red
    when "high"
      "6"  # Orange
    when "medium"
      "5"  # Yellow
    when "low"
      "2"  # Green
    else
      "1"  # Blue (default)
    end
  end
end
