class Festival < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :location, presence: true
  validates :budget, presence: true, numericality: { greater_than: 0 }

  validate :end_date_after_start_date

  enum :status, {
    planning: 0,
    scheduled: 1,
    active: 2,
    completed: 3,
    cancelled: 4
  }

  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :active, -> { where(status: :active) }
  scope :current_year, -> { where(start_date: Date.current.beginning_of_year..Date.current.end_of_year) }

  def duration_days
    return 0 unless start_date && end_date
    (end_date.to_date - start_date.to_date).to_i + 1
  end

  def upcoming?
    start_date && start_date > Time.current
  end

  def active?
    return false unless start_date && end_date
    Time.current.between?(start_date, end_date)
  end

  def completed?
    end_date && end_date < Time.current
  end

  def budget_formatted
    "¥#{budget&.to_i&.to_s(:delimited)}"
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, 'must be after start date')
    end
  end
end