class Festival < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :vendors, -> { where(vendor_applications: { status: 'approved' }) }, through: :vendor_applications, source: :user

  enum :status, {
    planning: 0,
    preparation: 1,
    active: 2,
    completed: 3,
    cancelled: 4
  }

  validates :name, :start_date, :end_date, :location, presence: true
  validates :name, length: { maximum: 100 }
  validates :location, length: { maximum: 200 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :budget, numericality: { greater_than_or_equal_to: 0, less_than: 100_000_000 }
  validate :end_date_after_start_date

  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Time.current, Time.current) }
  scope :past, -> { where('end_date < ?', Time.current) }

  def duration_days
    return 0 unless start_date && end_date
    ((end_date.to_date - start_date.to_date) + 1).to_i
  end

  def progress_percentage
    return 0 if tasks.empty?
    completed_tasks = tasks.where(status: 'completed').count
    (completed_tasks.to_f / tasks.count * 100).round(1)
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end
end
