class ForumThread < ApplicationRecord
  belongs_to :forum
  belongs_to :user
  has_many :forum_posts, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true, length: { maximum: 5000 }

  scope :pinned, -> { where(pinned: true) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :active, -> { where(locked: false) }

  def latest_post
    forum_posts.order(created_at: :desc).first
  end

  def post_count
    forum_posts.count
  end

  def last_activity
    latest_post&.created_at || updated_at
  end

  def participants
    User.joins(:forum_posts).where(forum_posts: { forum_thread: self }).distinct.includes(:avatar_attachment)
  end

  def participant_count
    participants.count
  end

  def can_be_accessed_by?(user)
    forum.can_be_accessed_by?(user)
  end

  def can_be_modified_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    user == self.user
  end

  def reaction_summary
    reactions.group(:reaction_type).count
  end

  def user_reaction(user)
    return nil unless user
    reactions.find_by(user: user)&.reaction_type
  end
end
