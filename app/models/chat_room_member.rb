class ChatRoomMember < ApplicationRecord
  belongs_to :chat_room
  belongs_to :user

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :chat_room_id }

  ROLES = %w[member admin moderator].freeze
  validates :role, inclusion: { in: ROLES }

  scope :admins, -> { where(role: "admin") }
  scope :moderators, -> { where(role: "moderator") }
  scope :active, -> { where("last_read_at > ?", 15.minutes.ago) }

  def admin?
    role == "admin"
  end

  def moderator?
    role == "moderator"
  end

  def can_moderate?
    admin? || moderator?
  end

  def mark_as_read!
    update(last_read_at: Time.current)
  end

  def unread_count
    return 0 unless last_read_at
    chat_room.chat_messages.where("created_at > ?", last_read_at).count
  end

  def active?
    last_read_at && last_read_at > 15.minutes.ago
  end

  def online_status
    return "online" if active?
    return "away" if last_read_at && last_read_at > 1.hour.ago
    "offline"
  end
end
