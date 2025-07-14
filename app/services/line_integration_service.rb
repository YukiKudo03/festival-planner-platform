class LineIntegrationService
  require "line/bot"

  def initialize(line_integration)
    @integration = line_integration
    @client = build_line_client
  end

  def authenticate_line_account
    begin
      profile = @client.get_profile(@integration.line_user_id) if @integration.line_user_id

      {
        success: true,
        line_user_id: profile&.dig("userId") || generate_temp_user_id,
        display_name: profile&.dig("displayName"),
        picture_url: profile&.dig("pictureUrl")
      }
    rescue => e
      Rails.logger.error "LINE authentication failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def test_connection
    begin
      # Test by getting bot info
      response = @client.get_bot_info
      response.is_a?(Net::HTTPOK)
    rescue => e
      Rails.logger.error "LINE connection test failed: #{e.message}"
      false
    end
  end

  def sync_groups
    begin
      # In a real implementation, this would fetch group information from LINE API
      # For now, we'll simulate group discovery

      # Note: LINE Bot API doesn't provide direct group listing
      # Groups are typically discovered through incoming messages

      Rails.logger.info "Group sync initiated for integration #{@integration.id}"
      true
    rescue => e
      Rails.logger.error "Group sync failed: #{e.message}"
      false
    end
  end

  def send_message(text, group_id = nil)
    begin
      message = {
        type: "text",
        text: text
      }

      if group_id.present?
        # Send to specific group
        response = @client.push_message(group_id, message)
      else
        # Send to all active groups
        @integration.line_groups.active_groups.each do |group|
          @client.push_message(group.line_group_id, message)
        end
        return true
      end

      response.is_a?(Net::HTTPOK)
    rescue => e
      Rails.logger.error "Failed to send LINE message: #{e.message}"
      false
    end
  end

  def register_webhook(webhook_url)
    begin
      # Register webhook URL with LINE
      response = @client.set_webhook_endpoint_url(webhook_url)

      if response.is_a?(Net::HTTPOK)
        { success: true, webhook_url: webhook_url }
      else
        { success: false, error: "Webhook registration failed: #{response.body}" }
      end
    rescue => e
      Rails.logger.error "Webhook registration failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def process_webhook_event(event)
    case event["type"]
    when "message"
      process_message_event(event)
    when "join"
      process_join_event(event)
    when "leave"
      process_leave_event(event)
    when "memberJoined"
      process_member_joined_event(event)
    when "memberLeft"
      process_member_left_event(event)
    else
      Rails.logger.info "Unhandled LINE event type: #{event['type']}"
    end
  end

  def get_group_info(group_id)
    begin
      response = @client.get_group_summary(group_id)

      if response.is_a?(Net::HTTPOK)
        JSON.parse(response.body)
      else
        nil
      end
    rescue => e
      Rails.logger.error "Failed to get group info: #{e.message}"
      nil
    end
  end

  def get_group_member_count(group_id)
    begin
      response = @client.get_group_members_count(group_id)

      if response.is_a?(Net::HTTPOK)
        JSON.parse(response.body)["count"]
      else
        0
      end
    rescue => e
      Rails.logger.error "Failed to get group member count: #{e.message}"
      0
    end
  end

  private

  def build_line_client
    Line::Bot::Client.new do |config|
      config.channel_id = @integration.line_channel_id
      config.channel_secret = @integration.line_channel_secret
      config.channel_token = @integration.line_access_token
    end
  end

  def process_message_event(event)
    return unless event["source"]["type"] == "group"

    group_id = event["source"]["groupId"]
    user_id = event["source"]["userId"]
    message = event["message"]

    # Find or create group
    line_group = find_or_create_group(group_id)
    return unless line_group

    # Find or create user (this would need user mapping logic)
    user = find_user_by_line_id(user_id)

    # Create message record
    line_message = line_group.line_messages.create!(
      line_message_id: event["message"]["id"],
      message_text: message["text"] || "",
      message_type: message["type"],
      user: user,
      sender_line_user_id: user_id,
      line_timestamp: Time.at(event["timestamp"] / 1000.0)
    )

    # Update group activity
    line_group.update_activity!(line_message.line_timestamp)

    # Process message for task creation if enabled
    if line_group.auto_parse_enabled? && message["type"] == "text"
      LineTaskParsingJob.perform_later(line_message)
    end

    line_message
  rescue => e
    Rails.logger.error "Failed to process message event: #{e.message}"
    nil
  end

  def process_join_event(event)
    return unless event["source"]["type"] == "group"

    group_id = event["source"]["groupId"]
    line_group = find_or_create_group(group_id)

    if line_group
      # Send welcome message
      welcome_message = build_welcome_message
      send_message(welcome_message, group_id)

      # Update group info
      update_group_info(line_group)
    end
  end

  def process_leave_event(event)
    return unless event["source"]["type"] == "group"

    group_id = event["source"]["groupId"]
    line_group = @integration.line_groups.find_by(line_group_id: group_id)

    if line_group
      line_group.update!(is_active: false)
    end
  end

  def process_member_joined_event(event)
    return unless event["source"]["type"] == "group"

    group_id = event["source"]["groupId"]
    line_group = @integration.line_groups.find_by(line_group_id: group_id)

    if line_group
      joined_members = event["joined"]["members"]
      line_group.increment!(:member_count, joined_members.count)
    end
  end

  def process_member_left_event(event)
    return unless event["source"]["type"] == "group"

    group_id = event["source"]["groupId"]
    line_group = @integration.line_groups.find_by(line_group_id: group_id)

    if line_group
      left_members = event["left"]["members"]
      left_members.count.times { line_group.decrement_member_count! }
    end
  end

  def find_or_create_group(group_id)
    line_group = @integration.line_groups.find_by(line_group_id: group_id)

    unless line_group
      group_info = get_group_info(group_id)
      member_count = get_group_member_count(group_id)

      line_group = @integration.line_groups.create!(
        line_group_id: group_id,
        name: group_info&.dig("groupName") || "Group #{group_id[0..8]}",
        member_count: member_count,
        last_activity_at: Time.current
      )
    end

    line_group
  rescue => e
    Rails.logger.error "Failed to find or create group: #{e.message}"
    nil
  end

  def find_user_by_line_id(line_user_id)
    # In a real implementation, you'd need a mapping table between LINE user IDs and your users
    # For now, we'll return the integration owner as fallback
    @integration.user
  end

  def update_group_info(line_group)
    group_info = get_group_info(line_group.line_group_id)
    member_count = get_group_member_count(line_group.line_group_id)

    if group_info
      line_group.update!(
        name: group_info["groupName"],
        member_count: member_count,
        last_activity_at: Time.current
      )
    end
  rescue => e
    Rails.logger.error "Failed to update group info: #{e.message}"
  end

  def build_welcome_message
    festival_name = @integration.festival.name

    "🎭 #{festival_name} のLINE連携が開始されました！\n\n" \
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

  def generate_temp_user_id
    "temp_#{SecureRandom.hex(8)}"
  end
end
