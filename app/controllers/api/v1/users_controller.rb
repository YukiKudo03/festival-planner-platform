class Api::V1::UsersController < Api::V1::BaseController
  before_action :set_user, only: [ :show, :update ]
  before_action :authorize_user_access, only: [ :show, :update ]

  # GET /api/v1/users/me
  def me
    render json: {
      user: serialize_user_detailed(current_user)
    }
  end

  # GET /api/v1/users/:id
  def show
    render json: {
      user: serialize_user(@user)
    }
  end

  # PATCH/PUT /api/v1/users/:id
  def update
    if @user.update(user_params)
      render json: {
        user: serialize_user_detailed(@user),
        message: "User updated successfully"
      }
    else
      render json: {
        errors: @user.errors.full_messages,
        details: @user.errors.details
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/users/:id/festivals
  def festivals
    user = User.find(params[:id])
    authorize_user_access_for(user)

    festivals = user.festivals.includes(:users, :tasks)
    festivals = festivals.page(params[:page]).per(params[:per_page] || 20)

    render json: {
      festivals: festivals.map { |festival| serialize_festival(festival) },
      meta: pagination_meta(festivals)
    }
  end

  # GET /api/v1/users/:id/tasks
  def tasks
    user = User.find(params[:id])
    authorize_user_access_for(user)

    tasks = user.tasks.includes(:festival, :assigned_user)
    tasks = filter_tasks(tasks)
    tasks = tasks.page(params[:page]).per(params[:per_page] || 50)

    render json: {
      tasks: tasks.map { |task| serialize_task(task) },
      meta: pagination_meta(tasks)
    }
  end

  # GET /api/v1/users/:id/notifications
  def notifications
    user = User.find(params[:id])
    authorize_user_access_for(user)

    notifications = user.notifications.includes(:related_object)
    notifications = notifications.unread if params[:unread_only] == "true"
    notifications = notifications.page(params[:page]).per(params[:per_page] || 50)

    render json: {
      notifications: notifications.map { |notification| serialize_notification(notification) },
      meta: pagination_meta(notifications),
      unread_count: user.notifications.unread.count
    }
  end

  # PATCH /api/v1/users/:id/notifications/mark_all_read
  def mark_notifications_read
    user = User.find(params[:id])
    authorize_user_access_for(user)

    user.notifications.unread.update_all(read_at: Time.current)

    render json: {
      message: "All notifications marked as read",
      unread_count: 0
    }
  end

  # GET /api/v1/users/search
  def search
    users = User.where("name ILIKE ? OR email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    users = users.limit(params[:limit] || 20)

    render json: {
      users: users.map { |user| serialize_user_basic(user) }
    }
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_user_access
    authorize_user_access_for(@user)
  end

  def authorize_user_access_for(user)
    unless user == current_user || current_user.admin?
      render json: { error: "Access denied" }, status: :forbidden
    end
  end

  def user_params
    params.require(:user).permit(
      :name, :email, :phone, :bio, :timezone,
      user_preferences_attributes: [
        :dashboard_layout, :theme, :language, :date_format,
        :time_format, :notifications_enabled, :email_notifications,
        :push_notifications, :line_notifications
      ]
    )
  end

  def filter_tasks(tasks)
    tasks = tasks.where(status: params[:status]) if params[:status].present?
    tasks = tasks.where(priority: params[:priority]) if params[:priority].present?
    tasks = tasks.where("due_date >= ?", params[:due_from]) if params[:due_from].present?
    tasks = tasks.where("due_date <= ?", params[:due_to]) if params[:due_to].present?

    case params[:sort]
    when "due_date"
      tasks.order(:due_date)
    when "priority"
      tasks.order(priority: :desc)
    when "created"
      tasks.order(created_at: :desc)
    else
      tasks.order(:due_date)
    end
  end

  def serialize_user_basic(user)
    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      bio: user.bio,
      timezone: user.timezone,
      role: user.role,
      created_at: user.created_at.iso8601,
      updated_at: user.updated_at.iso8601
    }
  end

  def serialize_user_detailed(user)
    serialize_user(user).merge(
      festivals_count: user.festivals.count,
      tasks_count: user.tasks.count,
      notifications_unread_count: user.notifications.unread.count,
      user_preferences: user.user_preferences ? {
        dashboard_layout: user.user_preferences.dashboard_layout,
        theme: user.user_preferences.theme,
        language: user.user_preferences.language,
        date_format: user.user_preferences.date_format,
        time_format: user.user_preferences.time_format,
        notifications_enabled: user.user_preferences.notifications_enabled,
        email_notifications: user.user_preferences.email_notifications,
        push_notifications: user.user_preferences.push_notifications,
        line_notifications: user.user_preferences.line_notifications
      } : nil,
      line_integration: user.line_integration ? {
        active: user.line_integration.active,
        groups_count: user.line_integration.line_groups.count
      } : nil
    )
  end

  def serialize_festival(festival)
    {
      id: festival.id,
      name: festival.name,
      description: festival.description,
      start_date: festival.start_date&.iso8601,
      end_date: festival.end_date&.iso8601,
      status: festival.status,
      location: festival.location,
      budget: festival.budget,
      users_count: festival.users.count,
      tasks_count: festival.tasks.count
    }
  end

  def serialize_task(task)
    {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      due_date: task.due_date&.iso8601,
      progress: task.progress,
      festival: {
        id: task.festival.id,
        name: task.festival.name
      }
    }
  end

  def serialize_notification(notification)
    {
      id: notification.id,
      title: notification.title,
      message: notification.message,
      notification_type: notification.notification_type,
      read: notification.read?,
      created_at: notification.created_at.iso8601,
      related_object: notification.related_object ? {
        type: notification.related_object.class.name,
        id: notification.related_object.id
      } : nil
    }
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
