class Api::V1::Webhooks::DiscordController < Api::V1::Webhooks::BaseController
  
  # POST /api/v1/webhooks/discord
  def receive
    # Discord webhook verification
    unless verify_discord_signature
      webhook_error('Invalid Discord signature', :unauthorized)
      return
    end

    # Handle different Discord event types
    case request.headers['X-GitHub-Event'] || params[:type]
    when 'message'
      handle_message_event
    when 'interaction'
      handle_interaction_event
    when 'guild_member_add'
      handle_member_join_event
    else
      webhook_success('Discord event received but not processed')
    end
  end

  private

  def verify_discord_signature
    # Discord uses different signature verification
    # For now, we'll implement basic verification
    signature = request.headers['X-Signature-Ed25519']
    timestamp = request.headers['X-Signature-Timestamp']
    
    return false unless signature && timestamp

    # Discord uses Ed25519 signature verification
    # This would need the discord public key
    # For now, return true for development
    Rails.env.development? || verify_ed25519_signature(signature, timestamp)
  end

  def verify_ed25519_signature(signature, timestamp)
    # Implementation would depend on having Discord's public key
    # and using Ed25519 verification
    false
  end

  def handle_message_event
    message_content = params.dig(:data, :content) || params[:content]
    channel_id = params.dig(:data, :channel_id) || params[:channel_id]
    user_id = params.dig(:data, :author, :id) || params.dig(:author, :id)
    
    return webhook_success('Empty message') unless message_content.present?

    # Find Discord integration
    discord_integration = find_discord_integration(channel_id)
    return webhook_success('No integration found') unless discord_integration

    # Process task commands
    if task_command?(message_content)
      process_task_command(discord_integration, message_content, channel_id, user_id)
    elsif help_command?(message_content)
      send_help_message(discord_integration, channel_id)
    elsif status_command?(message_content)
      send_status_update(discord_integration, channel_id)
    end

    webhook_success('Message processed')
  end

  def handle_interaction_event
    # Handle Discord slash commands and button interactions
    interaction_type = params.dig(:data, :type) || params[:type]
    
    case interaction_type
    when 1 # PING
      render json: { type: 1 } # PONG
    when 2 # APPLICATION_COMMAND
      handle_slash_command
    when 3 # MESSAGE_COMPONENT
      handle_button_interaction
    else
      webhook_success('Interaction received')
    end
  end

  def handle_slash_command
    command_name = params.dig(:data, :name)
    
    case command_name
    when 'task'
      handle_task_slash_command
    when 'status'
      handle_status_slash_command
    when 'help'
      handle_help_slash_command
    else
      respond_to_interaction('Unknown command')
    end
  end

  def handle_task_slash_command
    options = params.dig(:data, :options) || []
    
    title = find_option_value(options, 'title')
    assignee = find_option_value(options, 'assignee')
    due_date = find_option_value(options, 'due_date')
    priority = find_option_value(options, 'priority') || 'medium'

    channel_id = params[:channel_id]
    discord_integration = find_discord_integration(channel_id)
    
    if discord_integration && title
      task = create_task_from_command(discord_integration, {
        title: title,
        assignee: assignee,
        due_date: due_date,
        priority: priority
      })
      
      if task.persisted?
        respond_to_interaction("✅ タスク「#{task.title}」を作成しました！")
      else
        respond_to_interaction("❌ タスクの作成に失敗しました: #{task.errors.full_messages.join(', ')}")
      end
    else
      respond_to_interaction('❌ タスクの作成に必要な情報が不足しています')
    end
  end

  def handle_status_slash_command
    channel_id = params[:channel_id]
    discord_integration = find_discord_integration(channel_id)
    
    if discord_integration
      status = generate_status_message(discord_integration.festival)
      respond_to_interaction(status)
    else
      respond_to_interaction('❌ 統合設定が見つかりません')
    end
  end

  def handle_help_slash_command
    help_message = generate_help_message
    respond_to_interaction(help_message, ephemeral: true)
  end

  def handle_button_interaction
    custom_id = params.dig(:data, :custom_id)
    
    case custom_id
    when /^complete_task_(\d+)$/
      task_id = $1.to_i
      complete_task_via_button(task_id)
    when /^assign_task_(\d+)$/
      task_id = $1.to_i
      show_assignment_modal(task_id)
    else
      respond_to_interaction('Unknown button interaction')
    end
  end

  def handle_member_join_event
    guild_id = params[:guild_id]
    user = params[:user]
    
    # Send welcome message with bot information
    welcome_message = generate_welcome_message(user[:username])
    
    # This would send a DM or channel message to the new member
    webhook_success('Member join processed')
  end

  def find_discord_integration(channel_id)
    # This would need a DiscordIntegration model
    # For now, return nil as placeholder
    nil
  end

  def task_command?(content)
    content.match?(/タスク[：:]\s*(.+)/i) ||
    content.match?(/task[：:]\s*(.+)/i) ||
    content.match?(/!task\s+(.+)/i)
  end

  def help_command?(content)
    content.match?(/help|ヘルプ|!help/i)
  end

  def status_command?(content)
    content.match?(/status|進捗|!status/i)
  end

  def process_task_command(discord_integration, content, channel_id, user_id)
    task_info = parse_task_from_message(content)
    return unless task_info

    task = create_task_from_command(discord_integration, task_info)
    
    if task.persisted?
      send_discord_message(
        channel_id,
        "✅ タスク「#{task.title}」を作成しました！",
        task_buttons(task)
      )
    else
      send_discord_message(
        channel_id,
        "❌ タスクの作成に失敗しました: #{task.errors.full_messages.join(', ')}"
      )
    end
  end

  def parse_task_from_message(content)
    # Similar to Slack parser
    title_match = content.match(/(?:タスク|task|!task)[：:]\s*(.+?)(?:\s|$|@|期限|優先度)/i)
    return nil unless title_match

    title = title_match[1].strip

    # Extract mentions (Discord format: <@user_id>)
    assignee_match = content.match(/<@(\d+)>/)
    assigned_user = nil
    if assignee_match
      # Find user by Discord user ID
      # This would need a mapping table
      assigned_user = find_user_by_discord_id(assignee_match[1])
    end

    due_date = extract_due_date_from_text(content)
    priority = extract_priority_from_text(content)

    {
      title: title,
      assigned_user: assigned_user,
      due_date: due_date,
      priority: priority
    }
  end

  def create_task_from_command(discord_integration, task_info)
    festival = discord_integration.festival
    task = festival.tasks.build(task_info)
    task.created_by = discord_integration.user
    task.status = 'pending'
    task.save
    task
  end

  def send_help_message(discord_integration, channel_id)
    help_message = generate_help_message
    send_discord_message(channel_id, help_message)
  end

  def send_status_update(discord_integration, channel_id)
    status_message = generate_status_message(discord_integration.festival)
    send_discord_message(channel_id, status_message)
  end

  def generate_help_message
    <<~HELP
      🤖 **Festival Planner Bot ヘルプ**

      **📋 タスク作成:**
      `/task title:タスク名 assignee:@ユーザー due_date:2024-12-25 priority:high`
      または
      `タスク: タスク名 @ユーザー 期限 優先度`

      **📊 状況確認:**
      `/status` または `status`

      **✅ タスク操作:**
      タスクメッセージのボタンを使用

      **📅 期限表現:**
      - 今日、明日、明後日
      - 12月25日、2024-12-25

      **⚠️ 優先度:**
      - urgent (緊急)
      - high (重要)  
      - medium (普通)
      - low (低)
    HELP
  end

  def generate_status_message(festival)
    tasks = festival.tasks
    
    <<~STATUS
      📊 **#{festival.name} - タスク状況**

      ⏳ 待機中: #{tasks.where(status: 'pending').count}件
      🔄 進行中: #{tasks.where(status: 'in_progress').count}件
      ✅ 完了: #{tasks.where(status: 'completed').count}件
      ⚠️ 期限切れ: #{tasks.where('due_date < ? AND status != ?', Date.current, 'completed').count}件

      📅 今日期限: #{tasks.where(due_date: Date.current).where.not(status: 'completed').count}件
      📅 明日期限: #{tasks.where(due_date: Date.current + 1.day).where.not(status: 'completed').count}件
    STATUS
  end

  def generate_welcome_message(username)
    <<~WELCOME
      👋 **#{username}さん、Festival Planner Discordサーバーへようこそ！**

      🤖 私はFestival Planner Botです。タスク管理をサポートします。

      **使い方:**
      - `/help` でコマンド一覧を表示
      - `/task` でタスクを作成  
      - `/status` で進捗を確認

      ご不明な点がございましたら、お気軽にお尋ねください！
    WELCOME
  end

  def task_buttons(task)
    [
      {
        type: 1,
        components: [
          {
            type: 2,
            style: 3,
            label: "完了",
            custom_id: "complete_task_#{task.id}",
            emoji: { name: "✅" }
          },
          {
            type: 2,
            style: 2,
            label: "担当者変更",
            custom_id: "assign_task_#{task.id}",
            emoji: { name: "👤" }
          }
        ]
      }
    ]
  end

  def find_option_value(options, name)
    option = options.find { |opt| opt[:name] == name }
    option ? option[:value] : nil
  end

  def find_user_by_discord_id(discord_user_id)
    # This would need a mapping table or user integration
    nil
  end

  def extract_due_date_from_text(text)
    # Similar to other parsers
    if text.match?(/今日/i)
      Date.current
    elsif text.match?(/明日/i)
      Date.current + 1.day
    elsif date_match = text.match(/(\d{1,2})月(\d{1,2})日/i)
      month, day = date_match[1].to_i, date_match[2].to_i
      Date.new(Date.current.year, month, day)
    elsif date_match = text.match(/(\d{4})-(\d{1,2})-(\d{1,2})/i)
      Date.new(date_match[1].to_i, date_match[2].to_i, date_match[3].to_i)
    end
  end

  def extract_priority_from_text(text)
    return 'urgent' if text.match?(/緊急|至急|urgent/i)
    return 'high' if text.match?(/重要|high/i)
    return 'low' if text.match?(/後で|低優先度|low/i)
    'medium'
  end

  def complete_task_via_button(task_id)
    task = Task.find_by(id: task_id)
    if task
      task.update(
        status: 'completed',
        completed_at: Time.current,
        completed_by_id: params.dig(:member, :user, :id) # Discord user
      )
      respond_to_interaction("✅ タスク「#{task.title}」を完了しました！")
    else
      respond_to_interaction("❌ タスクが見つかりません")
    end
  end

  def show_assignment_modal(task_id)
    # Discord modal for task assignment
    modal = {
      type: 9,
      data: {
        title: "タスク担当者変更",
        custom_id: "assign_modal_#{task_id}",
        components: [
          {
            type: 1,
            components: [
              {
                type: 4,
                custom_id: "assignee_input",
                label: "担当者 (ユーザーID or @mention)",
                style: 1,
                required: true
              }
            ]
          }
        ]
      }
    }
    
    render json: modal
  end

  def respond_to_interaction(content, ephemeral: false)
    response = {
      type: 4,
      data: {
        content: content,
        flags: ephemeral ? 64 : 0
      }
    }
    
    render json: response
  end

  def send_discord_message(channel_id, content, components = nil)
    # This would use Discord API to send message
    # Implementation depends on having Discord bot setup
    Rails.logger.info "Would send Discord message to #{channel_id}: #{content}"
    Rails.logger.info "Components: #{components}" if components
  end
end