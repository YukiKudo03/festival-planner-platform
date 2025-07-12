class LineWebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(event_data)
    Rails.logger.info "Processing LINE webhook event: #{event_data['type']}"
    
    case event_data['type']
    when 'message'
      process_message_event(event_data)
    when 'join'
      process_join_event(event_data)
    when 'leave'
      process_leave_event(event_data)
    when 'memberJoined'
      process_member_joined_event(event_data)
    when 'memberLeft'
      process_member_left_event(event_data)
    when 'follow'
      process_follow_event(event_data)
    when 'unfollow'
      process_unfollow_event(event_data)
    else
      Rails.logger.warn "Unhandled LINE event type: #{event_data['type']}"
    end
  rescue => e
    Rails.logger.error "Failed to process LINE webhook event: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def process_message_event(event_data)
    return unless event_data['source']['type'] == 'group'

    group_id = event_data['source']['groupId']
    user_id = event_data['source']['userId']
    message = event_data['message']

    # Find integration by group
    line_integration = find_integration_by_group(group_id)
    return unless line_integration

    # Find or create group
    line_group = find_or_create_group(line_integration, group_id)
    return unless line_group

    # Find user (this would need more sophisticated mapping in production)
    user = find_user_for_line_id(line_integration, user_id)

    # Create message record
    line_message = create_line_message(line_group, user, message, event_data)
    return unless line_message

    # Update group activity
    line_group.update_activity!(line_message.line_timestamp)

    # Process message for task creation if enabled
    if line_group.auto_parse_enabled? && message['type'] == 'text'
      LineTaskParsingJob.perform_later(line_message)
    end

    Rails.logger.info "Successfully processed LINE message: #{line_message.id}"
  rescue => e
    Rails.logger.error "Failed to process message event: #{e.message}"
    raise e
  end

  def process_join_event(event_data)
    return unless event_data['source']['type'] == 'group'

    group_id = event_data['source']['groupId']
    line_integration = find_integration_by_group(group_id)
    return unless line_integration

    line_group = find_or_create_group(line_integration, group_id)
    return unless line_group

    # Send welcome message
    welcome_message = build_welcome_message(line_integration.festival)
    line_integration.send_notification(welcome_message, group_id)

    # Update group info
    update_group_info(line_integration, line_group)

    Rails.logger.info "Bot joined group: #{group_id}"
  rescue => e
    Rails.logger.error "Failed to process join event: #{e.message}"
  end

  def process_leave_event(event_data)
    return unless event_data['source']['type'] == 'group'

    group_id = event_data['source']['groupId']
    line_integration = find_integration_by_group(group_id)
    return unless line_integration

    line_group = line_integration.line_groups.find_by(line_group_id: group_id)
    if line_group
      line_group.update!(is_active: false)
      Rails.logger.info "Bot left group: #{group_id}"
    end
  rescue => e
    Rails.logger.error "Failed to process leave event: #{e.message}"
  end

  def process_member_joined_event(event_data)
    return unless event_data['source']['type'] == 'group'

    group_id = event_data['source']['groupId']
    line_integration = find_integration_by_group(group_id)
    return unless line_integration

    line_group = line_integration.line_groups.find_by(line_group_id: group_id)
    if line_group
      joined_members = event_data['joined']['members']
      line_group.increment!(:member_count, joined_members.count)
      Rails.logger.info "#{joined_members.count} members joined group: #{group_id}"
    end
  rescue => e
    Rails.logger.error "Failed to process member joined event: #{e.message}"
  end

  def process_member_left_event(event_data)
    return unless event_data['source']['type'] == 'group'

    group_id = event_data['source']['groupId']
    line_integration = find_integration_by_group(group_id)
    return unless line_integration

    line_group = line_integration.line_groups.find_by(line_group_id: group_id)
    if line_group
      left_members = event_data['left']['members']
      left_members.count.times { line_group.decrement_member_count! }
      Rails.logger.info "#{left_members.count} members left group: #{group_id}"
    end
  rescue => e
    Rails.logger.error "Failed to process member left event: #{e.message}"
  end

  def process_follow_event(event_data)
    user_id = event_data['source']['userId']
    Rails.logger.info "User followed: #{user_id}"
    
    # In a production system, you might want to:
    # 1. Send a welcome message
    # 2. Link the LINE user to a platform user account
    # 3. Enable notifications for this user
  rescue => e
    Rails.logger.error "Failed to process follow event: #{e.message}"
  end

  def process_unfollow_event(event_data)
    user_id = event_data['source']['userId']
    Rails.logger.info "User unfollowed: #{user_id}"
    
    # In a production system, you might want to:
    # 1. Disable notifications for this user
    # 2. Clean up user mapping data
  rescue => e
    Rails.logger.error "Failed to process unfollow event: #{e.message}"
  end

  # Helper methods

  def find_integration_by_group(group_id)
    # Find integration that has this group
    LineGroup.joins(:line_integration)
             .where(line_group_id: group_id)
             .first&.line_integration ||
    # Fallback: find any active integration (for new groups)
    LineIntegration.active_integrations.first
  end

  def find_or_create_group(line_integration, group_id)
    line_group = line_integration.line_groups.find_by(line_group_id: group_id)
    
    unless line_group
      service = LineIntegrationService.new(line_integration)
      group_info = service.get_group_info(group_id)
      member_count = service.get_group_member_count(group_id)
      
      line_group = line_integration.line_groups.create!(
        line_group_id: group_id,
        name: group_info&.dig('groupName') || "Group #{group_id[0..8]}",
        member_count: member_count,
        last_activity_at: Time.current
      )
    end
    
    line_group
  rescue => e
    Rails.logger.error "Failed to find or create group: #{e.message}"
    nil
  end

  def find_user_for_line_id(line_integration, line_user_id)
    # In a production system, you would have a mapping table
    # between LINE user IDs and platform user accounts
    # For now, fallback to integration owner
    line_integration.user
  end

  def create_line_message(line_group, user, message, event_data)
    line_timestamp = Time.at(event_data['timestamp'] / 1000.0)
    
    line_group.line_messages.create!(
      line_message_id: message['id'],
      message_text: message['text'] || extract_message_content(message),
      message_type: message['type'],
      user: user,
      sender_line_user_id: event_data['source']['userId'],
      line_timestamp: line_timestamp
    )
  rescue => e
    Rails.logger.error "Failed to create line message: #{e.message}"
    nil
  end

  def extract_message_content(message)
    case message['type']
    when 'sticker'
      "[Sticker: #{message['packageId']}/#{message['stickerId']}]"
    when 'image'
      "[Image message]"
    when 'video'
      "[Video message]"
    when 'audio'
      "[Audio message]"
    when 'file'
      "[File: #{message['fileName']}]"
    when 'location'
      "[Location: #{message['title']}]"
    else
      "[#{message['type']} message]"
    end
  end

  def update_group_info(line_integration, line_group)
    service = LineIntegrationService.new(line_integration)
    group_info = service.get_group_info(line_group.line_group_id)
    member_count = service.get_group_member_count(line_group.line_group_id)
    
    if group_info
      line_group.update!(
        name: group_info['groupName'],
        member_count: member_count,
        last_activity_at: Time.current
      )
    end
  rescue => e
    Rails.logger.error "Failed to update group info: #{e.message}"
  end

  def build_welcome_message(festival)
    "🎭 #{festival.name} のLINE連携が開始されました！\n\n" \
    "📝 タスクの登録方法：\n" \
    "「タスク：準備作業をする」のようにメッセージを送信\n\n" \
    "📅 期限の指定：\n" \
    "「タスク：会場設営 明日まで」\n\n" \
    "👤 担当者の指定：\n" \
    "「タスク：音響チェック @田中さん」\n\n" \
    "❓ 進捗確認：\n" \
    "「進捗」または「状況」と送信\n\n" \
    "お祭りの準備、がんばりましょう！ 🎉"
  end
end