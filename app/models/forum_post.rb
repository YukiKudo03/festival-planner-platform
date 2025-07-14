class ForumPost < ApplicationRecord
  belongs_to :forum_thread
  belongs_to :user
  has_many :reactions, as: :reactable, dependent: :destroy
  has_many_attached :attachments

  validates :content, presence: true, length: { maximum: 5000 }

  scope :recent, -> { order(created_at: :desc) }

  after_create :update_thread_activity
  after_create :send_notification

  def can_be_modified_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    user == self.user && created_at > 1.hour.ago
  end

  def reaction_summary
    reactions.group(:reaction_type).count
  end

  def user_reaction(user)
    return nil unless user
    reactions.find_by(user: user)&.reaction_type
  end

  def mention_users
    # @username パターンでメンションされたユーザーを抽出
    mentioned_usernames = content.scan(/@(\w+)/).flatten
    User.where(email: mentioned_usernames.map { |u| "#{u}@*" })
  end

  private

  def update_thread_activity
    forum_thread.touch
  end

  def send_notification
    # スレッド参加者への通知
    participants = forum_thread.participants.where.not(id: user.id)

    participants.each do |participant|
      NotificationService.create_notification(
        recipient: participant,
        sender: user,
        notifiable: self,
        notification_type: "forum_reply",
        title: "「#{forum_thread.title}」に新しい返信があります",
        message: content.truncate(100)
      )
    end

    # メンションされたユーザーへの通知
    mention_users.each do |mentioned_user|
      NotificationService.create_notification(
        recipient: mentioned_user,
        sender: user,
        notifiable: self,
        notification_type: "forum_mention",
        title: "フォーラムでメンションされました",
        message: content.truncate(100)
      )
    end
  end
end
