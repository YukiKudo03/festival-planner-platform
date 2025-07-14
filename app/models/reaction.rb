class Reaction < ApplicationRecord
  belongs_to :reactable, polymorphic: true
  belongs_to :user

  REACTION_TYPES = %w[like love laugh wow sad angry].freeze

  validates :reaction_type, presence: true, inclusion: { in: REACTION_TYPES }
  validates :user_id, uniqueness: { scope: [ :reactable_type, :reactable_id ] }

  scope :by_type, ->(type) { where(reaction_type: type) }

  def self.emoji_for(reaction_type)
    case reaction_type
    when "like" then "👍"
    when "love" then "❤️"
    when "laugh" then "😂"
    when "wow" then "😮"
    when "sad" then "😢"
    when "angry" then "😡"
    else "👍"
    end
  end

  def emoji
    self.class.emoji_for(reaction_type)
  end
end
