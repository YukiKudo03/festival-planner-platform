class LineGroup < ApplicationRecord
  belongs_to :line_integration
  has_many :line_messages, dependent: :destroy
  has_one :festival, through: :line_integration

  validates :line_group_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :line_integration_id, uniqueness: { scope: :line_group_id }

  serialize :group_settings, coder: JSON

  scope :active_groups, -> { where(is_active: true) }
  scope :recent_activity, -> { where('last_activity_at > ?', 24.hours.ago) }
  scope :by_integration, ->(integration) { where(line_integration: integration) }

  before_create :set_default_group_settings

  def group_settings
    super || default_group_settings
  end

  def active?
    is_active?
  end

  def recent_messages(limit = 50)
    line_messages.order(line_timestamp: :desc).limit(limit)
  end

  def unprocessed_messages
    line_messages.where(is_processed: false).order(:line_timestamp)
  end

  def update_activity!(timestamp = Time.current)
    update!(last_activity_at: timestamp)
  end

  def increment_member_count!
    increment!(:member_count)
  end

  def decrement_member_count!
    decrement!(:member_count) if member_count > 0
  end

  def can_create_tasks?
    active? && group_settings['task_creation_enabled']
  end

  def task_creation_enabled?
    group_settings['task_creation_enabled'] == true
  end

  def notification_enabled?
    group_settings['notifications_enabled'] == true
  end

  def auto_parse_enabled?
    group_settings['auto_parse_enabled'] == true
  end

  def send_message(text)
    return false unless active?
    
    line_integration.send_notification(text, line_group_id)
  end

  def process_pending_messages!
    unprocessed_messages.find_each do |message|
      LineTaskParserService.new(message).process_message
    end
  end

  def stats
    {
      total_messages: line_messages.count,
      processed_messages: line_messages.where(is_processed: true).count,
      created_tasks: line_messages.joins(:task).count,
      member_count: member_count,
      last_activity: last_activity_at,
      active_status: is_active
    }
  end

  private

  def set_default_group_settings
    self.group_settings = default_group_settings if group_settings.blank?
  end

  def default_group_settings
    {
      task_creation_enabled: true,
      notifications_enabled: true,
      auto_parse_enabled: true,
      require_keywords: false,
      allowed_users: [], # Empty means all users allowed
      restricted_mode: false,
      task_assignment_mode: 'auto', # 'auto', 'manual', 'none'
      default_task_priority: 'medium',
      notification_format: 'detailed', # 'detailed', 'summary', 'minimal'
      quiet_hours: {
        enabled: false,
        start: '22:00',
        end: '07:00'
      },
      keywords: {
        task_indicators: ['やること', 'タスク', 'TODO', '作業'],
        priority_high: ['緊急', '急ぎ', '重要'],
        priority_low: ['後で', 'あとで'],
        completion: ['完了', '終了', 'done', '済み']
      }
    }
  end
end