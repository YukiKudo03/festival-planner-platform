class User < ApplicationRecord
  include ApiAuthenticatable
  
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

  has_many :owned_festivals, class_name: 'Festival', dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :applied_festivals, through: :vendor_applications, source: :festival
  
  # レビュー関連
  has_many :application_reviews, foreign_key: 'reviewer_id', dependent: :destroy
  has_many :application_comments, dependent: :destroy
  has_many :reviewed_applications, through: :application_reviews, source: :vendor_application
  
  # 通知関連
  has_many :received_notifications, class_name: 'Notification', foreign_key: 'recipient_id', dependent: :destroy
  has_many :sent_notifications, class_name: 'Notification', foreign_key: 'sender_id', dependent: :nullify
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
        frequency: 'immediate'
      )
  end

  private

  def create_default_notification_settings
    NotificationSetting.create_defaults_for_user(self)
  end
end
