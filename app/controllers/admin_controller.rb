class AdminController < ApplicationController
  before_action :ensure_admin_access

  def dashboard
    authorize! :access, :admin_dashboard

    @statistics = {
      total_users: User.count,
      total_festivals: Festival.count,
      total_tasks: Task.count,
      total_vendor_applications: VendorApplication.count,
      users_by_role: User.group(:role).count,
      festivals_by_status: Festival.group(:status).count,
      recent_registrations: User.order(created_at: :desc).limit(10),
      recent_festivals: Festival.order(created_at: :desc).limit(5)
    }

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def users
    authorize! :access, :user_management

    @users = User.includes(:owned_festivals, :tasks, :vendor_applications)
                 .order(created_at: :desc)
                 .page(params[:page])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def monitoring
    authorize! :access, :system_monitoring

    @system_status = {
      database_status: check_database_status,
      redis_status: check_redis_status,
      disk_usage: check_disk_usage,
      memory_usage: check_memory_usage,
      recent_errors: get_recent_errors
    }

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def ensure_admin_access
    unless current_user&.system_admin? || current_user&.admin?
      flash[:alert] = "この機能にアクセスする権限がありません。"
      redirect_to root_path
    end
  end

  def check_database_status
    begin
      ActiveRecord::Base.connection.active?
      "OK"
    rescue
      "ERROR"
    end
  end

  def check_redis_status
    # Redis check if implemented
    "N/A"
  end

  def check_disk_usage
    # Simple disk usage check
    begin
      `df -h /`.split("\n")[1].split[4]
    rescue
      "N/A"
    end
  end

  def check_memory_usage
    # Simple memory usage check
    begin
      `free -m`.split("\n")[1].split[2]
    rescue
      "N/A"
    end
  end

  def get_recent_errors
    # This would typically come from log monitoring
    []
  end
end
