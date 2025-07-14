class OutlookCalendarService
  include Rails.application.routes.url_helpers

  GRAPH_API_BASE_URL = "https://graph.microsoft.com/v1.0"

  def initialize(calendar_integration)
    @integration = calendar_integration
    @access_token = @integration.access_token
  end

  def test_connection
    begin
      response = make_api_request("GET", "/me")

      if response.success?
        { success: true, message: "Outlook Calendar connection successful" }
      else
        { success: false, message: "API Error: #{response.code}" }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  def fetch_calendars
    begin
      response = make_api_request("GET", "/me/calendars")

      if response.success?
        calendars_data = JSON.parse(response.body)

        calendars = calendars_data["value"].map do |calendar|
          {
            id: calendar["id"],
            name: calendar["name"],
            description: calendar["description"],
            primary: calendar["isDefaultCalendar"] || false,
            access_role: calendar["canEdit"] ? "writer" : "reader",
            color: calendar["color"]
          }
        end

        { success: true, calendars: calendars }
      else
        { success: false, message: "Failed to fetch calendars: #{response.code}" }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  def create_events(events)
    created_events = []

    events.each do |event_data|
      begin
        outlook_event = build_outlook_event(event_data)
        response = make_api_request("POST", "/me/calendars/#{@integration.calendar_id}/events", outlook_event)

        if response.success?
          created_event = JSON.parse(response.body)

          created_events << {
            id: created_event["id"],
            web_link: created_event["webLink"],
            festival_event_type: event_data[:event_type],
            task_id: event_data[:task_id]
          }

          # Update task with calendar event ID if applicable
          if event_data[:task_id].present?
            task = Task.find_by(id: event_data[:task_id])
            task&.update(outlook_event_id: created_event["id"])
          end
        else
          Rails.logger.error "Failed to create Outlook event: #{response.code} - #{response.body}"
        end

      rescue => error
        Rails.logger.error "Failed to create Outlook Calendar event: #{error.message}"
        Rails.logger.error "Event data: #{event_data}"
      end
    end

    created_events
  end

  def update_event(event_id, event_data)
    begin
      outlook_event = build_outlook_event(event_data)
      response = make_api_request("PATCH", "/me/events/#{event_id}", outlook_event)

      if response.success?
        updated_event = JSON.parse(response.body)
        {
          success: true,
          event: {
            id: updated_event["id"],
            web_link: updated_event["webLink"]
          }
        }
      else
        {
          success: false,
          message: "Update failed: #{response.code}"
        }
      end
    rescue => error
      {
        success: false,
        message: error.message
      }
    end
  end

  def delete_event(event_id)
    begin
      response = make_api_request("DELETE", "/me/events/#{event_id}")

      if response.success?
        { success: true }
      else
        { success: false, message: "Delete failed: #{response.code}" }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  def fetch_events(options = {})
    begin
      start_time = (options[:start_date] || 1.month.ago).beginning_of_day.iso8601
      end_time = (options[:end_date] || 3.months.from_now).end_of_day.iso8601

      filter = "$filter=start/dateTime ge '#{start_time}' and end/dateTime le '#{end_time}'"
      order = "$orderby=start/dateTime"

      response = make_api_request("GET", "/me/calendars/#{@integration.calendar_id}/events?#{filter}&#{order}")

      if response.success?
        events_data = JSON.parse(response.body)

        calendar_events = events_data["value"].map do |event|
          # Skip our own festival events if requested
          if options[:exclude_festival_events] &&
             event["body"]["content"]&.include?("Festival Planner Platform")
            next
          end

          {
            id: event["id"],
            summary: event["subject"],
            description: event["body"]["content"],
            start_date: parse_outlook_datetime(event["start"]),
            end_date: parse_outlook_datetime(event["end"]),
            location: event["location"]["displayName"],
            web_link: event["webLink"],
            attendees: event["attendees"]&.map { |a| a["emailAddress"]["address"] } || [],
            created: Time.parse(event["createdDateTime"]),
            updated: Time.parse(event["lastModifiedDateTime"])
          }
        end.compact

        { success: true, events: calendar_events }
      else
        { success: false, message: "Failed to fetch events: #{response.code}" }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  def create_festival_calendar(festival)
    begin
      calendar_data = {
        name: "#{festival.name} - Festival Planning",
        description: "Calendar for #{festival.name} planning and events. Managed by Festival Planner Platform."
      }

      response = make_api_request("POST", "/me/calendars", calendar_data)

      if response.success?
        created_calendar = JSON.parse(response.body)

        {
          success: true,
          calendar: {
            id: created_calendar["id"],
            name: created_calendar["name"],
            web_link: "https://outlook.live.com/calendar/view/month"
          }
        }
      else
        { success: false, message: "Failed to create calendar: #{response.code}" }
      end
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
        category: "important"
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
        category: task.priority == "urgent" ? "important" : "normal"
      }
    end

    create_events(events_data)
  end

  private

  def make_api_request(method, endpoint, body = nil)
    url = "#{GRAPH_API_BASE_URL}#{endpoint}"

    headers = {
      "Authorization" => "Bearer #{@access_token}",
      "Content-Type" => "application/json"
    }

    # Refresh token if expired
    if @integration.token_expired?
      @integration.refresh_access_token!
      headers["Authorization"] = "Bearer #{@integration.access_token}"
    end

    case method.upcase
    when "GET"
      HTTParty.get(url, headers: headers)
    when "POST"
      HTTParty.post(url, headers: headers, body: body.to_json)
    when "PATCH"
      HTTParty.patch(url, headers: headers, body: body.to_json)
    when "DELETE"
      HTTParty.delete(url, headers: headers)
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end
  end

  def build_outlook_event(event_data)
    event = {
      subject: event_data[:summary],
      body: {
        contentType: "HTML",
        content: format_html_description(event_data[:description])
      },
      isAllDay: event_data[:start_date].is_a?(Date)
    }

    # Set start and end times
    if event_data[:start_date].is_a?(Date)
      # All-day event
      event[:start] = {
        dateTime: event_data[:start_date].to_time.iso8601,
        timeZone: "Asia/Tokyo"
      }
      event[:end] = {
        dateTime: (event_data[:end_date] || event_data[:start_date]).to_time.end_of_day.iso8601,
        timeZone: "Asia/Tokyo"
      }
    else
      # Timed event
      event[:start] = {
        dateTime: event_data[:start_date].iso8601,
        timeZone: "Asia/Tokyo"
      }
      event[:end] = {
        dateTime: (event_data[:end_date] || event_data[:start_date] + 1.hour).iso8601,
        timeZone: "Asia/Tokyo"
      }
    end

    # Set location
    if event_data[:location].present?
      event[:location] = {
        displayName: event_data[:location]
      }
    end

    # Set importance
    event[:importance] = event_data[:category] == "important" ? "high" : "normal"

    # Set categories
    event[:categories] = [ "Festival Planning", event_data[:event_type]&.humanize ].compact

    # Set reminders
    event[:isReminderOn] = true
    event[:reminderMinutesBeforeStart] = case event_data[:event_type]
    when "festival_main"
                                          24 * 60 # 1 day before
    when "task_deadline"
                                          60 # 1 hour before
    else
                                          15 # 15 minutes before
    end

    # Add custom properties (limited in Outlook)
    event[:singleValueExtendedProperties] = [
      {
        id: "String {66f5a359-4659-4830-9070-00047ec6ac6e} Name FestivalPlannerEvent",
        value: "true"
      },
      {
        id: "String {66f5a359-4659-4830-9070-00047ec6ac6e} Name EventType",
        value: event_data[:event_type]
      }
    ]

    if @integration.festival_id
      event[:singleValueExtendedProperties] << {
        id: "String {66f5a359-4659-4830-9070-00047ec6ac6e} Name FestivalId",
        value: @integration.festival_id.to_s
      }
    end

    if event_data[:task_id]
      event[:singleValueExtendedProperties] << {
        id: "String {66f5a359-4659-4830-9070-00047ec6ac6e} Name TaskId",
        value: event_data[:task_id].to_s
      }
    end

    event
  end

  def parse_outlook_datetime(datetime_obj)
    if datetime_obj["dateTime"]
      Time.parse(datetime_obj["dateTime"])
    else
      nil
    end
  end

  def format_html_description(description)
    return "" unless description.present?

    # Convert markdown-style formatting to HTML
    html_description = description.gsub(/\n/, "<br/>")
    html_description = html_description.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
    html_description = html_description.gsub(/\*(.*?)\*/, '<em>\1</em>')
    html_description = html_description.gsub(/🔗 (https?:\/\/[^\s]+)/, '<a href="\1">\1</a>')

    html_description
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
end
