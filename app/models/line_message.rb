class LineMessage < ApplicationRecord
  belongs_to :line_group
  belongs_to :user, optional: true
  belongs_to :task, optional: true
  has_one :line_integration, through: :line_group
  has_one :festival, through: :line_integration

  validates :line_message_id, presence: true, uniqueness: true
  validates :message_text, presence: true
  validates :message_type, presence: true

  serialize :parsed_content, coder: JSON
  serialize :processing_errors, coder: JSON

  enum :intent_type, {
    unknown: "unknown",
    task_creation: "task_creation",
    task_update: "task_update",
    task_completion: "task_completion",
    task_assignment: "task_assignment",
    status_inquiry: "status_inquiry",
    reminder_request: "reminder_request",
    general_message: "general_message"
  }, default: "unknown"

  scope :unprocessed, -> { where(is_processed: false) }
  scope :processed, -> { where(is_processed: true) }
  scope :with_tasks, -> { where.not(task_id: nil) }
  scope :recent, -> { order(line_timestamp: :desc) }
  scope :by_intent, ->(intent) { where(intent_type: intent) }
  scope :high_confidence, -> { where("confidence_score >= ?", 0.7) }

  before_save :set_default_timestamp

  def parsed_content
    super || {}
  end

  def processing_errors
    super || []
  end

  def processed?
    is_processed?
  end

  def has_task?
    task.present?
  end

  def high_confidence?
    confidence_score.to_f >= 0.7
  end

  def can_create_task?
    !processed? &&
    line_group.can_create_tasks? &&
    intent_type.in?([ "task_creation", "task_assignment" ]) &&
    high_confidence?
  end

  def sender_name
    sender_display_name.presence || user&.display_name || "Unknown User"
  end

  def process_message!
    return false if processed?

    result = LineTaskParserService.new(self).process_message

    if result[:success]
      update!(
        is_processed: true,
        intent_type: result[:intent_type],
        confidence_score: result[:confidence_score],
        parsed_content: result[:parsed_content],
        task: result[:task]
      )

      # Send confirmation if task was created
      send_confirmation_message if result[:task].present?

      true
    else
      add_processing_error(result[:error])
      false
    end
  rescue => e
    add_processing_error("Processing failed: #{e.message}")
    Rails.logger.error "Failed to process LINE message #{id}: #{e.message}"
    false
  end

  def retry_processing!
    return false if processed?

    # Clear previous errors
    self.processing_errors = []
    self.confidence_score = nil
    self.intent_type = "unknown"
    save!

    process_message!
  end

  def add_processing_error(error_message)
    errors_array = processing_errors || []
    errors_array << {
      message: error_message,
      timestamp: Time.current.iso8601
    }
    update!(processing_errors: errors_array)
  end

  def send_confirmation_message
    return unless has_task? && line_group.notification_enabled?

    confirmation_text = build_confirmation_message
    line_group.send_message(confirmation_text)
  end

  def extract_mentions
    return [] unless message_text.present?

    # Extract @mentions from message text
    message_text.scan(/@(\w+)/).flatten
  end

  def mentioned_users
    mentions = extract_mentions
    return [] if mentions.empty?

    # Find users by display name or username
    User.where(
      "first_name ILIKE ANY(ARRAY[?]) OR last_name ILIKE ANY(ARRAY[?]) OR email ILIKE ANY(ARRAY[?])",
      mentions.map { |m| "%#{m}%" },
      mentions.map { |m| "%#{m}%" },
      mentions.map { |m| "%#{m}%" }
    )
  end

  def notification_data
    {
      id: id,
      line_message_id: line_message_id,
      sender: sender_name,
      group_name: line_group.name,
      message_preview: message_text.truncate(100),
      intent_type: intent_type,
      confidence_score: confidence_score,
      has_task: has_task?,
      task_title: task&.title,
      timestamp: line_timestamp || created_at
    }
  end

  private

  def set_default_timestamp
    self.line_timestamp ||= Time.current
  end

  def build_confirmation_message
    case intent_type
    when "task_creation"
      "✅ タスクを作成しました：「#{task.title}」\n" \
      "📅 期限：#{task.due_date&.strftime('%Y年%m月%d日') || '未設定'}\n" \
      "👤 担当者：#{task.user&.display_name || '未設定'}"
    when "task_completion"
      "🎉 タスクが完了しました：「#{task.title}」"
    when "task_assignment"
      "📝 タスクが割り当てられました：「#{task.title}」\n" \
      "👤 担当者：#{task.user&.display_name}"
    else
      "📋 メッセージを処理しました"
    end
  end
end
