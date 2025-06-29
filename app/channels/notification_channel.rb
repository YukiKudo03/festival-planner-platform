class NotificationChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      stream_from "notifications_#{current_user.id}"
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def mark_as_read(data)
    if current_user
      notification = current_user.received_notifications.find_by(id: data['notification_id'])
      notification&.mark_as_read!
    end
  end
end
