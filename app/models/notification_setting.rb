class NotificationSetting < ApplicationRecord
  belongs_to :user

  FREQUENCIES = %w[immediate daily weekly never].freeze

  validates :notification_type, presence: true, inclusion: { in: Notification::NOTIFICATION_TYPES }
  validates :user_id, uniqueness: { scope: :notification_type }
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :enabled_for_email, -> { where(email_enabled: true) }
  scope :enabled_for_web, -> { where(web_enabled: true) }
  scope :enabled_for_line, -> { where(line_enabled: true) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :by_frequency, ->(freq) { where(frequency: freq) }

  def self.default_settings_for_user(user)
    Notification::NOTIFICATION_TYPES.map do |type|
      {
        user: user,
        notification_type: type,
        email_enabled: true,
        web_enabled: true,
        line_enabled: false, # デフォルトはOFF（連携設定後に有効化）
        frequency: 'immediate'
      }
    end
  end

  def self.create_defaults_for_user(user)
    default_settings_for_user(user).each do |setting_params|
      find_or_create_by(
        user: setting_params[:user],
        notification_type: setting_params[:notification_type]
      ) do |setting|
        setting.email_enabled = setting_params[:email_enabled]
        setting.web_enabled = setting_params[:web_enabled]
        setting.line_enabled = setting_params[:line_enabled]
        setting.frequency = setting_params[:frequency]
      end
    end
  end

  def should_send_email?
    email_enabled? && frequency != 'never'
  end

  def should_send_web?
    web_enabled? && frequency != 'never'
  end

  def should_send_line?
    line_enabled? && frequency != 'never'
  end

  def should_send_immediately?
    frequency == 'immediate'
  end

  # LINE連携に関する設定管理
  def enable_line_notifications!
    update!(line_enabled: true)
  end

  def disable_line_notifications!
    update!(line_enabled: false)
  end

  def self.enable_line_for_user(user, notification_types = nil)
    types = notification_types || Notification::NOTIFICATION_TYPES
    where(user: user, notification_type: types).update_all(line_enabled: true)
  end

  def self.disable_line_for_user(user, notification_types = nil)
    types = notification_types || Notification::NOTIFICATION_TYPES
    where(user: user, notification_type: types).update_all(line_enabled: false)
  end
end
