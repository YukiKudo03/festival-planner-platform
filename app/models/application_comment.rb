class ApplicationComment < ApplicationRecord
  belongs_to :vendor_application
  belongs_to :user

  validates :content, presence: true, length: { maximum: 1000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :public_comments, -> { where(internal: false) }
  scope :internal_comments, -> { where(internal: true) }

  def author_name
    user&.display_name || "Unknown"
  end

  def visibility_text
    internal? ? "内部コメント" : "公開コメント"
  end

  def can_be_seen_by?(viewer)
    return true if !internal?
    return true if viewer&.admin? || viewer&.committee_member?
    return true if viewer == user
    false
  end
end
