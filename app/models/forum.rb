class Forum < ApplicationRecord
  belongs_to :festival
  has_many :forum_threads, dependent: :destroy
  has_many :forum_posts, through: :forum_threads

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :category, presence: true

  CATEGORIES = %w[general announcements questions discussions events vendor].freeze
  
  validates :category, inclusion: { in: CATEGORIES }

  scope :public_forums, -> { where(private: false) }
  scope :private_forums, -> { where(private: true) }
  scope :by_category, ->(cat) { where(category: cat) }

  def public?
    !private?
  end

  def latest_activity
    forum_posts.order(created_at: :desc).first&.created_at || created_at
  end

  def thread_count
    forum_threads.count
  end

  def post_count
    forum_posts.count
  end

  def can_be_accessed_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    return true if public?
    
    # プライベートフォーラムの場合、関係者のみ
    private? && user.festivals.include?(festival)
  end
end
