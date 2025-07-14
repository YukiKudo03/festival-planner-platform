class ChatMessage < ApplicationRecord
  belongs_to :chat_room
  belongs_to :user
  has_many :reactions, as: :reactable, dependent: :destroy
  has_many_attached :attachments

  validates :content, presence: true, length: { maximum: 2000 }
  validates :message_type, presence: true

  MESSAGE_TYPES = %w[text image file system announcement].freeze
  validates :message_type, inclusion: { in: MESSAGE_TYPES }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(message_type: type) }
  scope :text_messages, -> { where(message_type: "text") }
  scope :system_messages, -> { where(message_type: "system") }

  after_create :broadcast_message
  after_create :update_room_activity
  after_create :send_notifications

  def text_message?
    message_type == "text"
  end

  def system_message?
    message_type == "system"
  end

  def image_message?
    message_type == "image"
  end

  def file_message?
    message_type == "file"
  end

  def announcement_message?
    message_type == "announcement"
  end

  def can_be_edited_by?(current_user)
    return false unless current_user
    return true if current_user.admin?
    return false if system_message?
    user == current_user && created_at > 5.minutes.ago
  end

  def can_be_deleted_by?(current_user)
    return false unless current_user
    return true if current_user.admin?
    return true if chat_room.member_role(current_user) == "admin"
    user == current_user && created_at > 15.minutes.ago
  end

  def mention_users
    # @username パターンでメンションされたユーザーを抽出
    mentioned_usernames = content.scan(/@(\w+)/).flatten
    chat_room.members.joins(:user).where(users: { email: mentioned_usernames.map { |u| "#{u}@%" } })
  end

  def formatted_content
    return content unless text_message?

    # メンションをリンクに変換
    formatted = content.gsub(/@(\w+)/) do |match|
      username = $1
      "<span class='mention'>#{match}</span>"
    end

    # URLをリンクに変換
    formatted.gsub(URI.regexp([ "http", "https" ])) do |url|
      "<a href='#{url}' target='_blank' rel='noopener'>#{url}</a>"
    end
  end

  def reaction_summary
    reactions.group(:reaction_type).count
  end

  def user_reaction(current_user)
    return nil unless current_user
    reactions.find_by(user: current_user)&.reaction_type
  end

  private

  def broadcast_message
    # ActionCableでリアルタイム配信
    ChatRoomChannel.broadcast_to(
      chat_room,
      {
        type: "new_message",
        message: {
          id: id,
          content: content,
          message_type: message_type,
          user: {
            id: user.id,
            name: user.display_name,
            avatar_url: user.avatar.attached? ? Rails.application.routes.url_helpers.url_for(user.avatar.variant(resize_to_limit: [ 40, 40 ])) : nil
          },
          created_at: created_at.iso8601,
          attachments: attachments.map do |attachment|
            {
              id: attachment.id,
              filename: attachment.blob.filename,
              url: Rails.application.routes.url_helpers.url_for(attachment)
            }
          end
        }
      }
    )
  end

  def update_room_activity
    # ルームの最終更新時刻を更新
    chat_room.touch
  end

  def send_notifications
    return if system_message?

    # ルームメンバーへの通知（送信者以外）
    chat_room.members.where.not(id: user.id).each do |member|
      # 最後の読み取り時刻から15分以上経過している場合のみ通知
      room_member = chat_room.chat_room_members.find_by(user: member)
      next if room_member&.last_read_at && room_member.last_read_at > 15.minutes.ago

      NotificationService.create_notification(
        recipient: member,
        sender: user,
        notifiable: self,
        notification_type: "chat_message",
        title: "#{chat_room.display_name_for(member)}に新しいメッセージ",
        message: content.truncate(50)
      )
    end

    # メンションされたユーザーへの通知
    mention_users.each do |mentioned_user|
      NotificationService.create_notification(
        recipient: mentioned_user,
        sender: user,
        notifiable: self,
        notification_type: "chat_mention",
        title: "チャットでメンションされました",
        message: content.truncate(50)
      )
    end
  end
end
