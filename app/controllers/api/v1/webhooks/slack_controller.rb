class Api::V1::Webhooks::SlackController < Api::V1::Webhooks::BaseController
  before_action :verify_slack_token, only: [:receive]

  # POST /api/v1/webhooks/slack
  def receive
    case params[:type]
    when 'url_verification'
      render json: { challenge: params[:challenge] }
    when 'event_callback'
      handle_event_callback
    else
      webhook_error('Unknown webhook type')
    end
  end

  private

  def verify_slack_token
    token = request.headers['HTTP_X_SLACK_REQUEST_TIMESTAMP']
    signature = request.headers['HTTP_X_SLACK_SIGNATURE']
    
    unless token && signature
      webhook_error('Missing Slack verification headers', :unauthorized)
      return
    end

    # Verify timestamp (within 5 minutes)
    timestamp = token.to_i
    if (Time.current.to_i - timestamp).abs > 300
      webhook_error('Invalid timestamp', :unauthorized)
      return
    end

    # Verify signature
    payload = request.body.read
    request.body.rewind

    signing_secret = ENV['SLACK_SIGNING_SECRET']
    expected_signature = 'v0=' + OpenSSL::HMAC.hexdigest(
      'SHA256',
      signing_secret,
      "v0:#{timestamp}:#{payload}"
    )

    unless signature == expected_signature
      webhook_error('Invalid signature', :unauthorized)
      return
    end
  end

  def handle_event_callback
    event = params[:event]
    
    case event[:type]
    when 'message'
      handle_message_event(event)
    when 'app_mention'
      handle_mention_event(event)
    when 'reaction_added'
      handle_reaction_event(event)
    else
      Rails.logger.info "Unhandled Slack event type: #{event[:type]}"
    end

    webhook_success('Event processed')
  end

  def handle_message_event(event)
    return if event[:bot_id].present? # Ignore bot messages
    return unless event[:text].present?

    # Find Slack integration
    slack_integration = find_slack_integration(event[:team], event[:channel])
    return unless slack_integration

    # Process task-related messages
    if task_command?(event[:text])
      process_task_command(slack_integration, event)
    end

    # Log message for potential processing
    SlackMessage.create!(
      slack_integration: slack_integration,
      channel_id: event[:channel],
      user_id: event[:user],
      message_text: event[:text],
      timestamp: event[:ts],
      event_type: 'message',
      processed: false
    )
  end

  def handle_mention_event(event)
    slack_integration = find_slack_integration(event[:team], event[:channel])
    return unless slack_integration

    # Bot was mentioned - process as command
    text = event[:text].gsub(/<@[^>]+>/, '').strip
    
    if text.downcase.include?('help')
      send_help_message(slack_integration, event[:channel])
    elsif text.downcase.include?('status') || text.downcase.include?('進捗')
      send_status_update(slack_integration, event[:channel])
    else
      # Try to parse as task command
      process_task_command(slack_integration, event)
    end

    webhook_success('Mention processed')
  end

  def handle_reaction_event(event)
    # Handle reactions like ✅ for task completion
    if event[:reaction] == 'white_check_mark' # ✅
      slack_integration = find_slack_integration(event[:team], event[:item][:channel])
      return unless slack_integration

      # Find related task and mark as complete
      slack_message = SlackMessage.find_by(
        slack_integration: slack_integration,
        timestamp: event[:item][:ts]
      )

      if slack_message&.related_task
        task = slack_message.related_task
        task.update(
          status: 'completed',
          completed_at: Time.current,
          completed_by: slack_integration.user
        )

        post_to_slack(
          slack_integration,
          event[:item][:channel],
          "✅ タスク「#{task.title}」が完了しました！"
        )
      end
    end

    webhook_success('Reaction processed')
  end

  def find_slack_integration(team_id, channel_id)
    # This would need a SlackIntegration model similar to LineIntegration
    # For now, return nil as this is a placeholder
    nil
  end

  def task_command?(text)
    text.match?(/タスク[：:]\s*(.+)/i) ||
    text.match?(/task[：:]\s*(.+)/i) ||
    text.match?(/todo[：:]\s*(.+)/i)
  end

  def process_task_command(slack_integration, event)
    # Parse task from message
    text = event[:text]
    
    # Extract task details using similar logic to LINE parser
    task_info = parse_task_from_text(text)
    return unless task_info

    # Create task
    festival = slack_integration.festival
    task = festival.tasks.build(task_info)
    task.created_by = slack_integration.user

    if task.save
      # Send confirmation
      confirmation = "✅ タスクを作成しました\n"
      confirmation += "📋 タイトル: #{task.title}\n"
      confirmation += "📅 期限: #{task.due_date&.strftime('%Y年%m月%d日')}\n" if task.due_date
      confirmation += "⚠️ 優先度: #{task.priority}\n" if task.priority
      confirmation += "👤 担当者: #{task.assigned_user&.name}\n" if task.assigned_user

      post_to_slack(slack_integration, event[:channel], confirmation)

      # Link message to task
      SlackMessage.create!(
        slack_integration: slack_integration,
        channel_id: event[:channel],
        user_id: event[:user],
        message_text: event[:text],
        timestamp: event[:ts],
        event_type: 'task_creation',
        related_task: task,
        processed: true
      )
    else
      post_to_slack(
        slack_integration,
        event[:channel],
        "❌ タスクの作成に失敗しました: #{task.errors.full_messages.join(', ')}"
      )
    end
  end

  def parse_task_from_text(text)
    # Similar parsing logic to LineTaskParserService
    title_match = text.match(/(?:タスク|task|todo)[：:]\s*(.+?)(?:\s|$|@|期限|優先度)/i)
    return nil unless title_match

    title = title_match[1].strip

    # Extract assignee
    assignee_match = text.match(/@(\w+)/i)
    assigned_user = nil
    if assignee_match
      # Find user by name or email
      assigned_user = User.where(
        'name ILIKE ? OR email ILIKE ?',
        "%#{assignee_match[1]}%",
        "%#{assignee_match[1]}%"
      ).first
    end

    # Extract due date
    due_date = extract_due_date(text)

    # Extract priority
    priority = extract_priority(text)

    {
      title: title,
      assigned_user: assigned_user,
      due_date: due_date,
      priority: priority,
      status: 'pending'
    }
  end

  def extract_due_date(text)
    # Simple date extraction - can be enhanced
    if text.match?(/今日/i)
      Date.current
    elsif text.match?(/明日/i)
      Date.current + 1.day
    elsif text.match?(/明後日/i)
      Date.current + 2.days
    elsif date_match = text.match(/(\d{1,2})月(\d{1,2})日/i)
      month, day = date_match[1].to_i, date_match[2].to_i
      Date.new(Date.current.year, month, day)
    elsif date_match = text.match(/(\d{4})-(\d{1,2})-(\d{1,2})/i)
      Date.new(date_match[1].to_i, date_match[2].to_i, date_match[3].to_i)
    end
  end

  def extract_priority(text)
    return 'urgent' if text.match?(/緊急|至急|urgent/i)
    return 'high' if text.match?(/重要|high/i)
    return 'low' if text.match?(/後で|低優先度|low/i)
    'medium'
  end

  def send_help_message(slack_integration, channel)
    help_text = <<~HELP
      🤖 Festival Planner Bot ヘルプ

      📋 タスク作成:
      `タスク: タスク名 @担当者 期限 優先度`
      例: `タスク: ステージ設営 @田中さん 明日 重要`

      📊 状況確認:
      `@bot 進捗` または `@bot status`

      ✅ タスク完了:
      タスク作成メッセージに ✅ リアクションを追加

      📅 対応可能な期限表現:
      - 今日、明日、明後日
      - 12月25日
      - 2024-12-25

      ⚠️ 優先度:
      - 緊急、至急
      - 重要
      - 後で、低優先度
    HELP

    post_to_slack(slack_integration, channel, help_text)
  end

  def send_status_update(slack_integration, channel)
    festival = slack_integration.festival
    tasks = festival.tasks

    status_text = <<~STATUS
      📊 #{festival.name} - タスク状況

      ⏳ 待機中: #{tasks.where(status: 'pending').count}件
      🔄 進行中: #{tasks.where(status: 'in_progress').count}件
      ✅ 完了: #{tasks.where(status: 'completed').count}件
      ⚠️ 期限切れ: #{tasks.where('due_date < ? AND status != ?', Date.current, 'completed').count}件

      📅 今日期限のタスク: #{tasks.where(due_date: Date.current).where.not(status: 'completed').count}件
      📅 明日期限のタスク: #{tasks.where(due_date: Date.current + 1.day).where.not(status: 'completed').count}件
    STATUS

    post_to_slack(slack_integration, channel, status_text)
  end

  def post_to_slack(slack_integration, channel, message)
    # This would use Slack Web API to post message
    # Implementation depends on having Slack integration setup
    Rails.logger.info "Would post to Slack channel #{channel}: #{message}"
  end
end