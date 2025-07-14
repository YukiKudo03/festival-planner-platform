class RealtimeUpdatesChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user

    # Subscribe to user-specific updates
    stream_from "user_#{current_user.id}_updates"

    # Subscribe to festival-specific updates if user has access
    festival_ids = accessible_festival_ids
    festival_ids.each do |festival_id|
      stream_from "festival_#{festival_id}_updates"
    end

    # Subscribe to global platform updates
    stream_from "platform_updates"

    logger.info "RealtimeUpdatesChannel: User #{current_user.id} subscribed to #{festival_ids.size + 2} streams"

    # Send initial connection confirmation
    transmit({
      type: "connection_established",
      user_id: current_user.id,
      subscribed_festivals: festival_ids,
      timestamp: Time.current.iso8601
    })
  end

  def unsubscribed
    logger.info "RealtimeUpdatesChannel: User #{current_user&.id} unsubscribed"
  end

  def ping(data)
    # Handle client ping for connection health check
    transmit({
      type: "pong",
      timestamp: Time.current.iso8601,
      server_time: Time.current.to_f
    })
  end

  def subscribe_to_festival(data)
    festival_id = data["festival_id"]
    return unless festival_id && current_user&.can_access_festival?(festival_id)

    stream_from "festival_#{festival_id}_updates"

    transmit({
      type: "festival_subscribed",
      festival_id: festival_id,
      timestamp: Time.current.iso8601
    })
  end

  def unsubscribe_from_festival(data)
    festival_id = data["festival_id"]
    return unless festival_id

    stop_stream_from "festival_#{festival_id}_updates"

    transmit({
      type: "festival_unsubscribed",
      festival_id: festival_id,
      timestamp: Time.current.iso8601
    })
  end

  def join_presence(data)
    location = data["location"] || "unknown"
    page = data["page"] || "unknown"

    # Track user presence
    presence_key = "presence_#{location}_#{current_user.id}"
    ActionCable.server.redis.setex(presence_key, 30, {
      user_id: current_user.id,
      user_name: current_user.display_name,
      location: location,
      page: page,
      last_seen: Time.current.iso8601
    }.to_json)

    # Broadcast presence update
    ActionCable.server.broadcast("presence_#{location}", {
      type: "user_joined",
      user: {
        id: current_user.id,
        name: current_user.display_name,
        avatar_url: current_user.avatar.attached? ? url_for(current_user.avatar) : nil
      },
      location: location,
      page: page,
      timestamp: Time.current.iso8601
    })

    # Schedule presence cleanup
    PresenceCleanupJob.set(wait: 35.seconds).perform_later(presence_key)
  end

  def leave_presence(data)
    location = data["location"] || "unknown"

    presence_key = "presence_#{location}_#{current_user.id}"
    ActionCable.server.redis.del(presence_key)

    # Broadcast presence update
    ActionCable.server.broadcast("presence_#{location}", {
      type: "user_left",
      user_id: current_user.id,
      location: location,
      timestamp: Time.current.iso8601
    })
  end

  def typing_start(data)
    return unless data["context"] && data["context_id"]

    context = data["context"] # 'chat_room', 'forum_thread', etc.
    context_id = data["context_id"]
    channel_name = "#{context}_#{context_id}_typing"

    # Broadcast typing indicator
    ActionCable.server.broadcast(channel_name, {
      type: "typing_start",
      user: {
        id: current_user.id,
        name: current_user.display_name
      },
      context: context,
      context_id: context_id,
      timestamp: Time.current.iso8601
    })

    # Auto-stop typing after 5 seconds
    TypingStopJob.set(wait: 5.seconds).perform_later(channel_name, current_user.id)
  end

  def typing_stop(data)
    return unless data["context"] && data["context_id"]

    context = data["context"]
    context_id = data["context_id"]
    channel_name = "#{context}_#{context_id}_typing"

    ActionCable.server.broadcast(channel_name, {
      type: "typing_stop",
      user_id: current_user.id,
      context: context,
      context_id: context_id,
      timestamp: Time.current.iso8601
    })
  end

  def request_live_data(data)
    data_type = data["type"]
    resource_id = data["resource_id"]

    case data_type
    when "festival_stats"
      festival = Festival.find_by(id: resource_id)
      return unless festival && current_user.can_access_festival?(festival.id)

      stats = RealtimeStatsService.new(festival).generate_stats
      transmit({
        type: "live_data_response",
        data_type: "festival_stats",
        resource_id: resource_id,
        data: stats,
        timestamp: Time.current.iso8601
      })

    when "budget_summary"
      festival = Festival.find_by(id: resource_id)
      return unless festival && current_user.can_access_festival?(festival.id)

      summary = RealtimeBudgetService.new(festival).generate_summary
      transmit({
        type: "live_data_response",
        data_type: "budget_summary",
        resource_id: resource_id,
        data: summary,
        timestamp: Time.current.iso8601
      })

    when "task_progress"
      festival = Festival.find_by(id: resource_id)
      return unless festival && current_user.can_access_festival?(festival.id)

      progress = RealtimeTaskService.new(festival).generate_progress
      transmit({
        type: "live_data_response",
        data_type: "task_progress",
        resource_id: resource_id,
        data: progress,
        timestamp: Time.current.iso8601
      })

    when "vendor_status"
      festival = Festival.find_by(id: resource_id)
      return unless festival && current_user.can_access_festival?(festival.id)

      status = RealtimeVendorService.new(festival).generate_status
      transmit({
        type: "live_data_response",
        data_type: "vendor_status",
        resource_id: resource_id,
        data: status,
        timestamp: Time.current.iso8601
      })
    end
  end

  def update_user_activity(data)
    activity_type = data["activity_type"]
    activity_data = data["activity_data"] || {}

    # Track user activity for analytics
    UserActivityTrackingJob.perform_later(
      current_user.id,
      activity_type,
      activity_data.merge(timestamp: Time.current.iso8601)
    )

    # Broadcast activity to relevant channels if needed
    case activity_type
    when "page_view"
      # Could be used for analytics dashboard
    when "feature_use"
      # Track feature usage for UX improvements
    when "error_encountered"
      # Track client-side errors for debugging
      ErrorReportingJob.perform_later(current_user.id, activity_data)
    end
  end

  private

  def accessible_festival_ids
    return [] unless current_user

    case current_user.role
    when "system_admin", "admin"
      Festival.pluck(:id)
    when "committee_member"
      current_user.owned_festivals.pluck(:id)
    when "vendor"
      current_user.applied_festivals.pluck(:id)
    else
      # For residents and volunteers, get festivals they're involved with
      involved_festival_ids = []

      # Festivals they have tasks in
      involved_festival_ids += current_user.tasks.joins(:festival).pluck("festivals.id")

      # Festivals they're chat members of
      involved_festival_ids += current_user.chat_rooms.joins(:festival).pluck("festivals.id")

      # Festivals they've posted in forums
      involved_festival_ids += current_user.forum_posts.joins(forum_thread: { forum: :festival }).pluck("festivals.id")

      involved_festival_ids.uniq
    end
  end
end
