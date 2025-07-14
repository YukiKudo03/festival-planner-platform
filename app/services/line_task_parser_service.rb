class LineTaskParserService
  TASK_KEYWORDS = [ "タスク", "やること", "TODO", "作業", "仕事", "タスクを", "やることを" ].freeze
  PRIORITY_KEYWORDS = {
    "high" => [ "緊急", "急ぎ", "重要", "至急", "最優先", "ASAP" ],
    "medium" => [ "普通", "通常", "中程度" ],
    "low" => [ "後で", "あとで", "低優先度", "暇な時" ]
  }.freeze
  COMPLETION_KEYWORDS = [ "完了", "終了", "done", "済み", "終わった", "できた" ].freeze
  ASSIGNMENT_KEYWORDS = [ "お願い", "担当", "割り当て", "assign", "@" ].freeze

  def initialize(line_message)
    @message = line_message
    @text = line_message.message_text
    @line_group = line_message.line_group
    @festival = @line_group.festival
  end

  def process_message
    return { success: false, error: "Message already processed" } if @message.processed?

    begin
      intent_result = analyze_intent(@text)

      case intent_result[:intent]
      when "task_creation"
        create_task_from_message(intent_result)
      when "task_completion"
        complete_task_from_message(intent_result)
      when "task_assignment"
        assign_task_from_message(intent_result)
      when "status_inquiry"
        handle_status_inquiry(intent_result)
      else
        {
          success: true,
          intent_type: "general_message",
          confidence_score: intent_result[:confidence],
          parsed_content: intent_result[:parsed_data],
          task: nil
        }
      end
    rescue => e
      Rails.logger.error "LineTaskParserService error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  def analyze_intent(text)
    normalized_text = normalize_text(text)
    confidence = 0.0
    intent = "unknown"
    parsed_data = {}

    # Task creation detection
    if contains_task_keywords?(normalized_text)
      intent = "task_creation"
      confidence += 0.4
      parsed_data = parse_task_details(normalized_text)
      confidence += parsed_data[:has_title] ? 0.3 : 0.0
      confidence += parsed_data[:has_deadline] ? 0.2 : 0.0
      confidence += parsed_data[:has_assignee] ? 0.1 : 0.0
    end

    # Task completion detection
    if contains_completion_keywords?(normalized_text)
      intent = "task_completion"
      confidence = 0.7
      parsed_data = parse_completion_details(normalized_text)
    end

    # Task assignment detection
    if contains_assignment_keywords?(normalized_text) || contains_mentions?(text)
      intent = intent == "unknown" ? "task_assignment" : intent
      confidence += 0.3
      parsed_data.merge!(parse_assignment_details(text))
    end

    # Status inquiry detection
    if contains_status_keywords?(normalized_text)
      intent = "status_inquiry"
      confidence = 0.6
      parsed_data = parse_status_inquiry(normalized_text)
    end

    {
      intent: intent,
      confidence: [ confidence, 1.0 ].min,
      parsed_data: parsed_data
    }
  end

  def create_task_from_message(intent_result)
    parsed_data = intent_result[:parsed_data]

    # Extract task details
    title = parsed_data[:title] || extract_title_from_text(@text)
    return { success: false, error: "Could not extract task title" } if title.blank?

    # Find or create user
    user = find_user_from_message || @line_group.line_integration.user

    # Create task
    task = @festival.tasks.build(
      title: title,
      description: parsed_data[:description] || @text,
      user: user,
      due_date: parsed_data[:deadline],
      priority: parsed_data[:priority] || "medium",
      status: "pending",
      created_via_line: true,
      line_message_id: @message.line_message_id
    )

    if task.save
      # Create notification
      NotificationService.send_task_assigned_notification(task, @message.user) if user != @message.user

      {
        success: true,
        intent_type: "task_creation",
        confidence_score: intent_result[:confidence],
        parsed_content: parsed_data,
        task: task
      }
    else
      {
        success: false,
        error: "Task creation failed: #{task.errors.full_messages.join(', ')}"
      }
    end
  end

  def complete_task_from_message(intent_result)
    parsed_data = intent_result[:parsed_data]
    task_title = parsed_data[:task_title]

    # Find task by title or recent tasks
    task = find_task_by_title(task_title) || find_recent_user_task

    return { success: false, error: "Could not find task to complete" } unless task

    old_status = task.status
    task.update!(status: "completed", completed_at: Time.current)

    # Send notification
    NotificationService.send_task_status_changed_notification(task, old_status)

    {
      success: true,
      intent_type: "task_completion",
      confidence_score: intent_result[:confidence],
      parsed_content: parsed_data,
      task: task
    }
  end

  def assign_task_from_message(intent_result)
    parsed_data = intent_result[:parsed_data]
    assignee = find_mentioned_user(parsed_data[:mentions]) || find_user_by_name(parsed_data[:assignee_name])

    return { success: false, error: "Could not find user to assign task" } unless assignee

    # If this is part of task creation, include assignment
    if intent_result[:intent] == "task_creation"
      return create_task_from_message(intent_result.merge(
        parsed_data: parsed_data.merge(assignee: assignee)
      ))
    end

    # Otherwise, find existing task to reassign
    task = find_recent_task_for_assignment
    return { success: false, error: "Could not find task to assign" } unless task

    old_assignee = task.user
    task.update!(user: assignee)

    # Send notifications
    NotificationService.send_task_assigned_notification(task, @message.user)

    {
      success: true,
      intent_type: "task_assignment",
      confidence_score: intent_result[:confidence],
      parsed_content: parsed_data,
      task: task
    }
  end

  def handle_status_inquiry(intent_result)
    parsed_data = intent_result[:parsed_data]

    # Get task status summary
    user_tasks = @festival.tasks.where(user: @message.user || @line_group.line_integration.user)
    status_summary = {
      pending: user_tasks.where(status: "pending").count,
      in_progress: user_tasks.where(status: "in_progress").count,
      completed: user_tasks.where(status: "completed").count,
      overdue: user_tasks.where("due_date < ? AND status != ?", Date.current, "completed").count
    }

    # Send status message back to LINE
    status_message = build_status_message(status_summary)
    @line_group.send_message(status_message)

    {
      success: true,
      intent_type: "status_inquiry",
      confidence_score: intent_result[:confidence],
      parsed_content: parsed_data.merge(status_summary: status_summary),
      task: nil
    }
  end

  # Text processing helpers
  def normalize_text(text)
    text.downcase.gsub(/[[:punct:]]/, " ").squish
  end

  def contains_task_keywords?(text)
    TASK_KEYWORDS.any? { |keyword| text.include?(keyword.downcase) }
  end

  def contains_completion_keywords?(text)
    COMPLETION_KEYWORDS.any? { |keyword| text.include?(keyword.downcase) }
  end

  def contains_assignment_keywords?(text)
    ASSIGNMENT_KEYWORDS.any? { |keyword| text.include?(keyword.downcase) }
  end

  def contains_mentions?(text)
    text.include?("@")
  end

  def contains_status_keywords?(text)
    [ "状況", "ステータス", "進捗", "status", "確認" ].any? { |keyword| text.downcase.include?(keyword.downcase) }
  end

  # Parsing helpers
  def parse_task_details(text)
    details = { has_title: false, has_deadline: false, has_assignee: false }

    # Extract title (text after task keyword)
    TASK_KEYWORDS.each do |keyword|
      if text.include?(keyword.downcase)
        parts = text.split(keyword.downcase, 2)
        if parts.length > 1
          title_part = parts[1].strip
          details[:title] = clean_title(title_part)
          details[:has_title] = details[:title].present?
          break
        end
      end
    end

    # Extract deadline
    details[:deadline] = extract_deadline(text)
    details[:has_deadline] = details[:deadline].present?

    # Extract priority
    details[:priority] = extract_priority(text)

    # Extract description
    details[:description] = extract_description(text)

    details
  end

  def parse_completion_details(text)
    {
      task_title: extract_completed_task_title(text)
    }
  end

  def parse_assignment_details(text)
    {
      mentions: extract_mentions(text),
      assignee_name: extract_assignee_name(text)
    }
  end

  def parse_status_inquiry(text)
    {
      inquiry_type: "general_status"
    }
  end

  # Extraction helpers
  def extract_title_from_text(text)
    # Remove LINE-specific formatting and extract meaningful title
    cleaned = text.gsub(/^(タスク|やること|TODO)[:：]?\s*/, "")
    cleaned = cleaned.split(/[。\n]/).first || cleaned
    cleaned.strip.presence
  end

  def clean_title(title)
    # Remove common prefixes and clean up
    title.gsub(/^(を|は|が)\s*/, "")
         .gsub(/\s*(です|だ|である)$/, "")
         .strip
         .presence
  end

  def extract_deadline(text)
    # Simple date extraction patterns
    date_patterns = [
      /(\d{1,2})[\/\-](\d{1,2})/,  # MM/DD or MM-DD
      /(今日|明日|明後日)/,
      /(\d{1,2})日/,
      /(月曜|火曜|水曜|木曜|金曜|土曜|日曜)/
    ]

    date_patterns.each do |pattern|
      match = text.match(pattern)
      next unless match

      case match[0]
      when "今日"
        return Date.current
      when "明日"
        return Date.current + 1.day
      when "明後日"
        return Date.current + 2.days
      when /(\d{1,2})[\/\-](\d{1,2})/
        month, day = match[1].to_i, match[2].to_i
        return Date.new(Date.current.year, month, day) rescue nil
      when /(\d{1,2})日/
        day = match[1].to_i
        return Date.new(Date.current.year, Date.current.month, day) rescue nil
      end
    end

    nil
  end

  def extract_priority(text)
    PRIORITY_KEYWORDS.each do |priority, keywords|
      return priority if keywords.any? { |keyword| text.include?(keyword.downcase) }
    end
    "medium"
  end

  def extract_description(text)
    # Extract additional context beyond the title
    lines = text.split(/[。\n]/)
    lines.length > 1 ? lines[1..-1].join("\n").strip : nil
  end

  def extract_completed_task_title(text)
    # Extract task title from completion message
    COMPLETION_KEYWORDS.each do |keyword|
      if text.include?(keyword)
        parts = text.split(keyword)
        return parts.first.strip if parts.any?
      end
    end
    nil
  end

  def extract_mentions(text)
    text.scan(/@(\w+)/).flatten
  end

  def extract_assignee_name(text)
    # Extract name after assignment keywords
    ASSIGNMENT_KEYWORDS.each do |keyword|
      next unless text.include?(keyword)

      parts = text.split(keyword, 2)
      next unless parts.length > 1

      name_part = parts[1].strip.split(/\s+/).first
      return name_part if name_part.present?
    end
    nil
  end

  # User and task finding helpers
  def find_user_from_message
    return @message.user if @message.user.present?

    # Try to find user by LINE user ID
    line_integration = @line_group.line_integration
    User.joins(:owned_festivals)
        .where(festivals: { id: @festival.id })
        .first
  end

  def find_mentioned_user(mentions)
    return nil if mentions.blank?

    mentions.each do |mention|
      user = User.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
                       "%#{mention}%", "%#{mention}%", "%#{mention}%").first
      return user if user
    end
    nil
  end

  def find_user_by_name(name)
    return nil if name.blank?

    User.where("first_name ILIKE ? OR last_name ILIKE ?", "%#{name}%", "%#{name}%").first
  end

  def find_task_by_title(title)
    return nil if title.blank?

    @festival.tasks.where("title ILIKE ?", "%#{title}%")
             .order(created_at: :desc)
             .first
  end

  def find_recent_user_task
    user = @message.user || @line_group.line_integration.user
    @festival.tasks.where(user: user)
             .where.not(status: "completed")
             .order(created_at: :desc)
             .first
  end

  def find_recent_task_for_assignment
    @festival.tasks.where.not(status: "completed")
             .order(created_at: :desc)
             .first
  end

  def build_status_message(status_summary)
    "📊 タスク状況\n" \
    "⏳ 待機中: #{status_summary[:pending]}件\n" \
    "🔄 進行中: #{status_summary[:in_progress]}件\n" \
    "✅ 完了: #{status_summary[:completed]}件\n" \
    "⚠️ 期限切れ: #{status_summary[:overdue]}件"
  end
end
