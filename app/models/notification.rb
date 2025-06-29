class Notification < ApplicationRecord
  belongs_to :recipient, class_name: 'User'
  belongs_to :sender, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true

  NOTIFICATION_TYPES = %w[
    task_deadline_reminder
    task_overdue
    task_assigned
    task_status_changed
    festival_created
    festival_updated
    vendor_application_submitted
    vendor_application_approved
    vendor_application_rejected
    system_announcement
  ].freeze

  validates :notification_type, presence: true, inclusion: { in: NOTIFICATION_TYPES }
  validates :title, presence: true
  validates :recipient, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :for_user, ->(user) { where(recipient: user) }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current) if unread?
  end

  def mark_as_unread!
    update!(read_at: nil) if read?
  end

  def self.mark_all_as_read_for_user(user)
    for_user(user).unread.update_all(read_at: Time.current)
  end

  def self.cleanup_old_notifications(days = 90)
    where('created_at < ?', days.days.ago).delete_all
  end
end
