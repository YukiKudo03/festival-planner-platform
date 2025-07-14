# LINE Bot API Configuration
require "line/bot"

# Load environment variables for LINE API
Rails.application.configure do
  config.line_bot = {
    channel_id: ENV["LINE_CHANNEL_ID"],
    channel_secret: ENV["LINE_CHANNEL_SECRET"],
    channel_token: ENV["LINE_ACCESS_TOKEN"]
  }

  # LINE integration settings
  config.line_integration.merge!({
    webhook_signature_validation: Rails.env.production?,
    debug_mode: Rails.env.development?,
    default_timeout: 30.seconds,
    message_size_limit: 5000, # characters
    max_groups_per_integration: 50,
    max_messages_per_group_per_hour: 100
  })
end

# Validate LINE configuration in production
if Rails.env.production?
  required_vars = %w[LINE_CHANNEL_ID LINE_CHANNEL_SECRET LINE_ACCESS_TOKEN]
  missing_vars = required_vars.select { |var| ENV[var].blank? }

  if missing_vars.any?
    Rails.logger.warn "Missing LINE environment variables: #{missing_vars.join(', ')}"
    Rails.logger.warn "LINE integration will be disabled"
  end
end

# Initialize LINE Bot client factory
class LineBotClientFactory
  def self.create(channel_id:, channel_secret:, channel_token:)
    Line::Bot::Client.new do |config|
      config.channel_id = channel_id
      config.channel_secret = channel_secret
      config.channel_token = channel_token
    end
  end

  def self.default_client
    return nil unless ENV["LINE_CHANNEL_ID"].present?

    create(
      channel_id: ENV["LINE_CHANNEL_ID"],
      channel_secret: ENV["LINE_CHANNEL_SECRET"],
      channel_token: ENV["LINE_ACCESS_TOKEN"]
    )
  end
end
