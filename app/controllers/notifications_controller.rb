class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:show, :update, :destroy]

  def index
    @notifications = current_user.received_notifications
                                 .includes(:sender, :notifiable)
                                 .recent
                                 .page(params[:page])
                                 .per(20)
    
    @unread_count = current_user.unread_notifications_count
    @filter = params[:filter] || 'all'
    
    case @filter
    when 'unread'
      @notifications = @notifications.unread
    when 'read'
      @notifications = @notifications.read
    when 'type'
      @notifications = @notifications.by_type(params[:type]) if params[:type].present?
    end
  end

  def show
    @notification.mark_as_read! if @notification.unread?
    redirect_to notification_target_path(@notification)
  end

  def update
    if params[:mark_as_read] == 'true'
      @notification.mark_as_read!
      render json: { status: 'read', message: '既読にしました' }
    elsif params[:mark_as_unread] == 'true'
      @notification.mark_as_unread!
      render json: { status: 'unread', message: '未読にしました' }
    else
      render json: { error: 'Invalid action' }, status: :unprocessable_entity
    end
  end

  def destroy
    @notification.destroy
    redirect_to notifications_path, notice: '通知を削除しました。'
  end

  private

  def set_notification
    @notification = current_user.received_notifications.find(params[:id])
  end

  def notification_target_path(notification)
    case notification.notifiable_type
    when 'Task'
      if notification.notifiable&.festival
        festival_task_path(notification.notifiable.festival, notification.notifiable)
      else
        notifications_path
      end
    when 'Festival'
      festival_path(notification.notifiable) if notification.notifiable
    when 'VendorApplication'
      if notification.notifiable&.festival
        festival_vendor_application_path(notification.notifiable.festival, notification.notifiable)
      else
        notifications_path
      end
    else
      notifications_path
    end
  rescue
    notifications_path
  end
end
