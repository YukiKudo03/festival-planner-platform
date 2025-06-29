class NotificationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification_settings, only: [:index, :edit]
  before_action :set_notification_setting, only: [:update]

  def index
    @notification_settings = current_user.notification_settings.includes(:user)
    @notification_types = Notification::NOTIFICATION_TYPES
  end

  def edit
    @notification_setting = current_user.notification_settings.find(params[:id])
  end

  def update
    if @notification_setting.update(notification_setting_params)
      redirect_to notification_settings_path, notice: '通知設定を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_notification_settings
    # Ensure all notification types have settings
    Notification::NOTIFICATION_TYPES.each do |type|
      current_user.notification_settings.find_or_create_by(notification_type: type) do |setting|
        setting.email_enabled = true
        setting.web_enabled = true
        setting.frequency = 'immediate'
      end
    end
  end

  def set_notification_setting
    @notification_setting = current_user.notification_settings.find(params[:id])
  end

  def notification_setting_params
    params.require(:notification_setting).permit(:email_enabled, :web_enabled, :frequency)
  end
end
