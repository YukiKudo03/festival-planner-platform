class Api::V1::NotificationsController < Api::V1::BaseController
  before_action :set_notification, only: [ :show, :update, :destroy, :mark_read ]

  # GET /api/v1/notifications
  def index
    notifications = current_user.notifications.includes(:related_object)

    # Filtering
    notifications = notifications.unread if params[:unread_only] == "true"
    notifications = notifications.where(notification_type: params[:type]) if params[:type].present?
    notifications = notifications.where("created_at >= ?", params[:since]) if params[:since].present?

    # Sorting
    notifications = notifications.order(created_at: :desc)

    # Pagination
    notifications = notifications.page(params[:page]).per(params[:per_page] || 50)

    render json: {
      notifications: notifications.map { |notification| serialize_notification(notification) },
      meta: pagination_meta(notifications),
      summary: {
        total_count: current_user.notifications.count,
        unread_count: current_user.notifications.unread.count,
        types_count: current_user.notifications.group(:notification_type).count
      }
    }
  end

  # GET /api/v1/notifications/:id
  def show
    authorize_notification_access

    render json: {
      notification: serialize_notification_detailed(@notification)
    }
  end

  # PATCH /api/v1/notifications/:id
  def update
    authorize_notification_access

    if @notification.update(notification_params)
      render json: {
        notification: serialize_notification_detailed(@notification),
        message: "Notification updated successfully"
      }
    else
      render json: {
        errors: @notification.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/notifications/:id
  def destroy
    authorize_notification_access

    @notification.destroy
    render json: {
      message: "Notification deleted successfully"
    }
  end

  # PATCH /api/v1/notifications/:id/mark_read
  def mark_read
    authorize_notification_access

    @notification.mark_as_read!

    render json: {
      notification: serialize_notification(@notification),
      message: "Notification marked as read"
    }
  end

  # PATCH /api/v1/notifications/mark_all_read
  def mark_all_read
    count = current_user.notifications.unread.count
    current_user.notifications.unread.update_all(read_at: Time.current)

    render json: {
      message: "#{count} notifications marked as read",
      unread_count: 0
    }
  end

  # DELETE /api/v1/notifications/clear_all
  def clear_all
    count = current_user.notifications.count
    current_user.notifications.destroy_all

    render json: {
      message: "#{count} notifications cleared",
      notifications_count: 0
    }
  end

  # GET /api/v1/notifications/summary
  def summary
    notifications = current_user.notifications

    render json: {
      total_count: notifications.count,
      unread_count: notifications.unread.count,
      types_summary: notifications.group(:notification_type).count,
      recent_count: notifications.where("created_at >= ?", 24.hours.ago).count,
      priority_summary: {
        high: notifications.joins(:related_object).where(
          related_objects: { priority: "high" }
        ).count,
        urgent: notifications.where(
          notification_type: [ "task_overdue", "deadline_warning", "emergency" ]
        ).count
      },
      weekly_trend: (0..6).map do |days_ago|
        date = days_ago.days.ago.beginning_of_day
        {
          date: date.strftime("%Y-%m-%d"),
          count: notifications.where(
            created_at: date..date.end_of_day
          ).count
        }
      end.reverse
    }
  end

  # POST /api/v1/notifications/test
  def test
    # Create a test notification for API testing
    notification = NotificationService.create_notification(
      user: current_user,
      type: "api_test",
      title: "API Test Notification",
      message: "This is a test notification created via API at " + Time.current.to_s,
      related_object: nil
    )

    render json: {
      notification: serialize_notification_detailed(notification),
      message: "Test notification created successfully"
    }, status: :created
  end

  # GET /api/v1/notifications/settings
  def settings
    settings = current_user.notification_settings

    render json: {
      settings: {
        email_enabled: settings&.email_enabled,
        push_enabled: settings&.push_enabled,
        line_enabled: settings&.line_enabled,
        frequency: settings&.frequency,
        quiet_hours_start: settings&.quiet_hours_start,
        quiet_hours_end: settings&.quiet_hours_end,
        types: {
          task_assigned: settings&.task_assigned,
          task_completed: settings&.task_completed,
          task_overdue: settings&.task_overdue,
          deadline_warning: settings&.deadline_warning,
          festival_updates: settings&.festival_updates,
          vendor_application: settings&.vendor_application,
          payment_updates: settings&.payment_updates,
          line_integration: settings&.line_integration
        }
      }
    }
  end

  # PATCH /api/v1/notifications/settings
  def update_settings
    settings = current_user.notification_settings || current_user.build_notification_settings

    if settings.update(notification_settings_params)
      render json: {
        settings: serialize_notification_settings(settings),
        message: "Notification settings updated successfully"
      }
    else
      render json: {
        errors: settings.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Notification not found" }, status: :not_found
  end

  def authorize_notification_access
    unless @notification.user == current_user
      render json: { error: "Access denied" }, status: :forbidden
    end
  end

  def notification_params
    params.require(:notification).permit(:read_at)
  end

  def notification_settings_params
    params.require(:notification_settings).permit(
      :email_enabled, :push_enabled, :line_enabled, :frequency,
      :quiet_hours_start, :quiet_hours_end, :task_assigned,
      :task_completed, :task_overdue, :deadline_warning,
      :festival_updates, :vendor_application, :payment_updates,
      :line_integration
    )
  end

  def serialize_notification(notification)
    {
      id: notification.id,
      title: notification.title,
      message: notification.message,
      notification_type: notification.notification_type,
      read: notification.read?,
      priority: determine_priority(notification),
      created_at: notification.created_at.iso8601,
      read_at: notification.read_at&.iso8601,
      related_object: notification.related_object ? {
        type: notification.related_object.class.name,
        id: notification.related_object.id,
        name: notification.related_object.try(:title) ||
              notification.related_object.try(:name) ||
              "#{notification.related_object.class.name} ##{notification.related_object.id}"
      } : nil
    }
  end

  def serialize_notification_detailed(notification)
    serialize_notification(notification).merge(
      updated_at: notification.updated_at.iso8601,
      metadata: notification.metadata || {},
      actions: available_actions(notification)
    )
  end

  def serialize_notification_settings(settings)
    {
      email_enabled: settings.email_enabled,
      push_enabled: settings.push_enabled,
      line_enabled: settings.line_enabled,
      frequency: settings.frequency,
      quiet_hours_start: settings.quiet_hours_start,
      quiet_hours_end: settings.quiet_hours_end,
      types: {
        task_assigned: settings.task_assigned,
        task_completed: settings.task_completed,
        task_overdue: settings.task_overdue,
        deadline_warning: settings.deadline_warning,
        festival_updates: settings.festival_updates,
        vendor_application: settings.vendor_application,
        payment_updates: settings.payment_updates,
        line_integration: settings.line_integration
      }
    }
  end

  def determine_priority(notification)
    case notification.notification_type
    when "task_overdue", "deadline_warning", "emergency"
      "high"
    when "task_assigned", "payment_updates"
      "medium"
    else
      "low"
    end
  end

  def available_actions(notification)
    actions = [ "mark_read", "delete" ]

    case notification.notification_type
    when "task_assigned"
      actions << "view_task"
    when "vendor_application"
      actions << "review_application"
    when "payment_updates"
      actions << "view_payment"
    end

    actions
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      per_page: collection.limit_value,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end
end
