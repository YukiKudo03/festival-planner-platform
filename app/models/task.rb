class Task < ApplicationRecord
  belongs_to :user
  belongs_to :festival

  enum :priority, {
    low: 0,
    medium: 1,
    high: 2,
    urgent: 3
  }

  enum :status, {
    pending: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3
  }

  validates :title, :due_date, presence: true
  validates :title, length: { maximum: 200 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validate :due_date_within_festival_period

  scope :overdue, -> { where('due_date < ? AND status != ?', Time.current, statuses[:completed]) }
  scope :due_soon, -> { where('due_date BETWEEN ? AND ? AND status != ?', Time.current, 3.days.from_now, statuses[:completed]) }
  scope :by_priority, -> { order(:priority) }
  scope :by_due_date, -> { order(:due_date) }

  def overdue?
    due_date < Time.current && !completed?
  end

  def due_soon?
    due_date.between?(Time.current, 3.days.from_now) && !completed?
  end

  private

  def due_date_within_festival_period
    return unless due_date && festival&.start_date && festival&.end_date
    unless due_date.between?(festival.start_date - 6.months, festival.end_date + 1.month)
      errors.add(:due_date, 'should be within reasonable festival planning period')
    end
  end
end
