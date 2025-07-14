class Task < ApplicationRecord
  belongs_to :user
  belongs_to :festival

  # Active Storage attachments
  has_many_attached :attachments
  has_many_attached :images

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

  # LINE連携関連
  attr_accessor :created_via_line
  has_many :line_messages, dependent: :nullify

  scope :overdue, -> { where("due_date < ? AND status != ?", Time.current, statuses[:completed]) }
  scope :due_soon, -> { where("due_date BETWEEN ? AND ? AND status != ?", Time.current, 3.days.from_now, statuses[:completed]) }
  scope :by_priority, -> { order(:priority) }
  scope :by_due_date, -> { order(:due_date) }
  scope :created_via_line, -> { joins(:line_messages).distinct }
  scope :with_line_context, -> { includes(:line_messages) }

  # 通知関連
  has_many :notifications, as: :notifiable, dependent: :destroy

  after_update :send_status_change_notification
  after_create :send_task_assigned_notification

  def overdue?
    due_date < Time.current && !completed?
  end

  def due_soon?
    due_date.between?(Time.current, 3.days.from_now) && !completed?
  end

  # LINE連携関連メソッド
  def created_from_line?
    line_messages.any?
  end

  def originating_line_message
    line_messages.where(intent_type: "task_creation").first
  end

  def line_group_context
    originating_line_message&.line_group
  end

  def priority_label
    case priority
    when "low"
      "低"
    when "medium"
      "中"
    when "high"
      "高"
    when "urgent"
      "緊急"
    else
      "未設定"
    end
  end

  def status_label
    case status
    when "pending"
      "待機中"
    when "in_progress"
      "進行中"
    when "completed"
      "完了"
    when "cancelled"
      "キャンセル"
    else
      "不明"
    end
  end

  def line_notification_context
    return {} unless created_from_line?

    {
      source_message: originating_line_message&.message_text,
      source_group: line_group_context&.name,
      confidence_score: originating_line_message&.confidence_score,
      sender: originating_line_message&.sender_name
    }
  end

  def send_line_completion_notification
    return unless created_from_line? && completed?

    festival.line_integrations.active_integrations.each do |integration|
      next unless integration.notification_preferences["task_completed"]

      message = "✅ タスクが完了しました\n" \
                "タスク：#{title}\n" \
                "完了者：#{user&.display_name}\n" \
                "完了時刻：#{Time.current.strftime('%Y年%m月%d日 %H:%M')}"

      integration.send_notification(message, line_group_context&.line_group_id)
    end
  end

  private

  def due_date_within_festival_period
    return unless due_date && festival&.start_date && festival&.end_date
    unless due_date.between?(festival.start_date - 6.months, festival.end_date + 1.month)
      errors.add(:due_date, "should be within reasonable festival planning period")
    end
  end

  def send_status_change_notification
    if saved_change_to_status?
      old_status = status_before_last_save
      NotificationService.send_task_status_changed_notification(self, old_status)

      # LINE連携タスクの場合は完了通知を送信
      if status == "completed"
        send_line_completion_notification
      end
    end
  end

  def send_task_assigned_notification
    # タスク作成時の通知（作成者がアサイン者とみなす）
    NotificationService.send_task_assigned_notification(self, nil)
  end
end
