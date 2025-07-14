class User < ApplicationRecord
  include ApiAuthenticatable

  has_many :api_keys, dependent: :destroy
  has_many :api_requests, dependent: :destroy

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, {
    resident: 0,
    volunteer: 1,
    vendor: 2,
    committee_member: 3,
    admin: 4,
    system_admin: 5,
    platform_visitor: 6
  }

  validates :first_name, :last_name, presence: true
  validates :phone, format: { with: /\A[\d\-\(\)\+\s]+\z/, message: "Invalid phone format" }, allow_blank: true

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  has_many :owned_festivals, class_name: "Festival", dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :applied_festivals, through: :vendor_applications, source: :festival

  # レビュー関連
  has_many :application_reviews, foreign_key: "reviewer_id", dependent: :destroy
  has_many :application_comments, dependent: :destroy
  has_many :reviewed_applications, through: :application_reviews, source: :vendor_application

  # 通知関連
  has_many :received_notifications, class_name: "Notification", foreign_key: "recipient_id", dependent: :destroy
  has_many :sent_notifications, class_name: "Notification", foreign_key: "sender_id", dependent: :nullify
  has_many :notification_settings, dependent: :destroy

  # Active Storage attachments
  has_one_attached :avatar

  # フォーラム関連
  has_many :forum_threads, dependent: :destroy
  has_many :forum_posts, dependent: :destroy
  has_many :reactions, dependent: :destroy

  # チャット関連
  has_many :chat_messages, dependent: :destroy
  has_many :chat_room_members, dependent: :destroy
  has_many :chat_rooms, through: :chat_room_members

  # 支払い関連
  has_many :payments, dependent: :destroy

  # ユーザー設定関連
  has_one :user_preference, dependent: :destroy

  # LINE連携関連
  has_many :line_integrations, dependent: :destroy
  has_many :line_messages, dependent: :nullify
  has_many :line_groups, through: :line_integrations

  after_create :create_default_notification_settings

  def unread_notifications_count
    received_notifications.unread.count
  end

  def has_unread_notifications?
    unread_notifications_count > 0
  end

  def notification_setting_for(notification_type)
    notification_settings.find_by(notification_type: notification_type) ||
      notification_settings.build(
        notification_type: notification_type,
        email_enabled: true,
        web_enabled: true,
        frequency: "immediate"
      )
  end

  # LINE連携関連メソッド
  def has_active_line_integrations?
    line_integrations.active_integrations.any?
  end

  def line_integration_for_festival(festival)
    line_integrations.find_by(festival: festival)
  end

  def can_receive_line_notifications?
    has_active_line_integrations? &&
    line_integrations.any? { |integration| integration.can_send_notifications? }
  end

  def line_user_id_for_integration(integration)
    # LINEユーザーIDとプラットフォームユーザーのマッピング
    # 実装では、別途LineUserMappingテーブルを作成することも検討
    integration.line_user_id if integration.user == self
  end

  # API関連メソッド
  def available_api_scopes
    base_scopes = %w[festivals:read tasks:read budgets:read]

    case role
    when "admin", "system_admin"
      ApiKey::SCOPES
    when "committee_member"
      base_scopes + %w[festivals:write tasks:write budgets:write vendors:read analytics:read]
    when "vendor"
      base_scopes + %w[vendors:read payments:read]
    else
      base_scopes
    end
  end

  def create_api_key!(name, key_type: "personal", scopes: nil, options: {})
    scopes ||= available_api_scopes

    api_keys.create!(
      name: name,
      key_type: key_type,
      scopes: scopes & available_api_scopes, # 許可されたスコープのみ
      ip_whitelist: options[:ip_whitelist],
      expires_at: options[:expires_at]
    )
  end

  def active_api_keys
    api_keys.active.where("expires_at IS NULL OR expires_at > ?", Time.current)
  end

  def api_usage_summary(period: 30.days)
    {
      total_requests: api_requests.where("created_at > ?", period.ago).count,
      total_api_keys: api_keys.count,
      active_api_keys: active_api_keys.count,
      last_api_access: last_api_access_at,
      top_endpoints: api_requests
                      .where("created_at > ?", period.ago)
                      .group(:endpoint)
                      .order("count_all DESC")
                      .limit(5)
                      .count
    }
  end

  private

  def create_default_notification_settings
    NotificationSetting.create_defaults_for_user(self)
  end
end
