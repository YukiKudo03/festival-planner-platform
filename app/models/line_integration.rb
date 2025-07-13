class LineIntegration < ApplicationRecord
  belongs_to :festival
  belongs_to :user
  has_many :line_groups, dependent: :destroy
  has_many :line_messages, through: :line_groups

  enum :status, {
    inactive: 0,
    active: 1,
    error: 2,
    suspended: 3
  }

  validates :line_channel_id, presence: true, uniqueness: true
  validates :line_channel_secret, presence: true
  validates :line_access_token, presence: true
  validates :festival_id, uniqueness: { scope: :user_id }

  serialize :settings, coder: JSON
  serialize :notification_preferences, coder: JSON

  scope :active_integrations, -> { where(is_active: true, status: :active) }
  scope :for_festival, ->(festival) { where(festival: festival) }
  scope :recent_activity, -> { where('last_webhook_received_at > ?', 1.hour.ago) }

  before_create :set_default_settings
  after_create :initialize_webhook

  def settings
    super || default_settings
  end

  def notification_preferences
    super || default_notification_preferences
  end

  def active?
    is_active? && status == 'active'
  end

  def can_send_notifications?
    active? && line_access_token.present?
  end

  def webhook_configured?
    webhook_url.present?
  end

  def sync_groups!
    return false unless active?
    
    LineIntegrationService.new(self).sync_groups
    update!(last_sync_at: Time.current)
  rescue => e
    Rails.logger.error "Failed to sync LINE groups for integration #{id}: #{e.message}"
    update!(status: :error)
    false
  end

  def test_connection
    return false unless line_access_token.present?
    
    LineIntegrationService.new(self).test_connection
  rescue => e
    Rails.logger.error "LINE connection test failed for integration #{id}: #{e.message}"
    false
  end

  def send_notification(message, group_id = nil)
    return false unless can_send_notifications?
    
    LineIntegrationService.new(self).send_message(message, group_id)
  rescue => e
    Rails.logger.error "Failed to send LINE notification for integration #{id}: #{e.message}"
    false
  end

  def update_activity!
    update!(last_webhook_received_at: Time.current)
  end

  def encryption_key
    Rails.application.credentials.line_encryption_key || 'default_key'
  end

  def encrypted_access_token
    return nil unless line_access_token.present?
    
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = Digest::SHA256.digest(encryption_key)
    Base64.encode64(cipher.update(line_access_token) + cipher.final)
  end

  def decrypt_access_token(encrypted_token)
    return nil unless encrypted_token.present?
    
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.decrypt
    cipher.key = Digest::SHA256.digest(encryption_key)
    cipher.update(Base64.decode64(encrypted_token)) + cipher.final
  end

  private

  def set_default_settings
    self.settings = default_settings if settings.blank?
    self.notification_preferences = default_notification_preferences if notification_preferences.blank?
  end

  def default_settings
    {
      auto_task_creation: true,
      task_reminder_enabled: true,
      group_sync_interval: 1.hour.to_i,
      message_parsing_enabled: true,
      debug_mode: Rails.env.development?,
      webhook_signature_verification: true,
      allowed_message_types: ['text', 'sticker'],
      task_keywords: ['タスク', 'やること', 'TODO', '作業', '仕事'],
      priority_keywords: {
        'high' => ['緊急', '急ぎ', '重要', '至急'],
        'medium' => ['普通', '通常'],
        'low' => ['後で', 'あとで', '低優先度']
      }
    }
  end

  def default_notification_preferences
    {
      task_created: true,
      task_assigned: true,
      task_completed: true,
      task_overdue: true,
      deadline_reminder: true,
      festival_updates: true,
      system_notifications: false,
      notification_times: {
        start: '09:00',
        end: '18:00'
      },
      quiet_hours_enabled: true,
      mention_only: false
    }
  end

  def initialize_webhook
    return if Rails.env.test?
    LineWebhookSetupJob.perform_later(self) if line_channel_id.present?
  end
end