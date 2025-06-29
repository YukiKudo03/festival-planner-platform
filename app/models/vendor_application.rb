class VendorApplication < ApplicationRecord
  belongs_to :festival
  belongs_to :user

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
    cancelled: 3
  }

  validates :business_name, :business_type, :description, presence: true
  validates :business_name, length: { maximum: 100 }
  validates :business_type, length: { maximum: 50 }
  validates :description, length: { maximum: 2000 }
  validates :requirements, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: { scope: :festival_id, message: 'can only apply once per festival' }

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  def can_be_approved?
    pending?
  end

  def can_be_rejected?
    pending? || approved?
  end
end
