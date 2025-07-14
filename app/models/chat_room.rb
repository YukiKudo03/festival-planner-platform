class ChatRoom < ApplicationRecord
  belongs_to :festival
  has_many :chat_messages, dependent: :destroy
  has_many :chat_room_members, dependent: :destroy
  has_many :members, through: :chat_room_members, source: :user
  has_many :reactions, as: :reactable, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :room_type, presence: true

  ROOM_TYPES = %w[general private direct group announcement].freeze
  validates :room_type, inclusion: { in: ROOM_TYPES }

  scope :public_rooms, -> { where(private: false) }
  scope :private_rooms, -> { where(private: true) }
  scope :by_type, ->(type) { where(room_type: type) }

  def public?
    !private?
  end

  def direct_message?
    room_type == "direct"
  end

  def group_chat?
    room_type == "group"
  end

  def announcement_channel?
    room_type == "announcement"
  end

  def latest_message
    chat_messages.order(created_at: :desc).first
  end

  def message_count
    chat_messages.count
  end

  def active_members_count
    chat_room_members.where("last_read_at > ?", 15.minutes.ago).count
  end

  def unread_count_for(user)
    member = chat_room_members.find_by(user: user)
    return 0 unless member

    if member.last_read_at
      chat_messages.where("created_at > ?", member.last_read_at).count
    else
      chat_messages.count
    end
  end

  def can_be_accessed_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    return true if public?

    # プライベートルームの場合、メンバーかどうかをチェック
    members.include?(user)
  end

  def can_send_messages?(user)
    return false unless can_be_accessed_by?(user)
    return false if announcement_channel? && !user.admin? && !user.committee_member?
    true
  end

  def add_member(user, role: "member")
    chat_room_members.find_or_create_by(user: user) do |member|
      member.role = role
      member.joined_at = Time.current
    end
  end

  def remove_member(user)
    chat_room_members.find_by(user: user)&.destroy
  end

  def member_role(user)
    chat_room_members.find_by(user: user)&.role
  end

  def admin_members
    chat_room_members.where(role: "admin").includes(:user)
  end

  # ダイレクトメッセージルーム用のヘルパー
  def other_user(current_user)
    return nil unless direct_message?
    members.where.not(id: current_user.id).first
  end

  def display_name_for(current_user)
    if direct_message?
      other_user(current_user)&.display_name || "Unknown User"
    else
      name
    end
  end
end
