class LineNotificationJob < ApplicationJob
  queue_as :default

  def perform(line_integration_id, message, group_id = nil, options = {})
    line_integration = LineIntegration.find(line_integration_id)

    Rails.logger.info "Sending LINE notification via integration #{line_integration.id}"

    begin
      # Check if integration is active and can send notifications
      unless line_integration.can_send_notifications?
        Rails.logger.warn "LINE integration #{line_integration.id} cannot send notifications"
        return
      end

      # Check notification hours if enabled
      unless within_notification_hours?(line_integration, options)
        Rails.logger.info "Skipping notification due to quiet hours for integration #{line_integration.id}"
        return
      end

      service = LineIntegrationService.new(line_integration)
      success = service.send_message(message, group_id)

      if success
        Rails.logger.info "Successfully sent LINE notification via integration #{line_integration.id}"
        line_integration.update_activity!
      else
        Rails.logger.error "Failed to send LINE notification via integration #{line_integration.id}"
      end

    rescue => e
      Rails.logger.error "LINE notification job failed for integration #{line_integration.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Mark integration as error if multiple failures
      if line_integration.last_webhook_received_at &&
         line_integration.last_webhook_received_at < 1.hour.ago
        line_integration.update!(status: :error)
      end

      raise e
    end
  end

  private

  def within_notification_hours?(line_integration, options)
    # Skip time check if this is an urgent notification
    return true if options[:urgent] == true

    # Check integration's notification preferences
    prefs = line_integration.notification_preferences
    return true unless prefs["quiet_hours_enabled"]

    times = prefs["notification_times"]
    return true unless times && times["start"] && times["end"]

    current_time = Time.current.strftime("%H:%M")
    start_time = times["start"]
    end_time = times["end"]

    if start_time < end_time
      # Normal time range (e.g., 09:00 to 18:00)
      current_time >= start_time && current_time <= end_time
    else
      # Overnight range (e.g., 22:00 to 07:00)
      current_time >= start_time || current_time <= end_time
    end
  end
end
