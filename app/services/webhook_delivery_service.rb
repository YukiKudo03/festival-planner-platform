class WebhookDeliveryService
  include Rails.application.routes.url_helpers

  WEBHOOK_EVENTS = %w[
    task_created task_updated task_completed task_assigned
    festival_created festival_updated
    payment_confirmed payment_failed
    notification_sent
    user_joined user_left
  ].freeze

  def self.deliver(event, payload, options = {})
    new(event, payload, options).deliver
  end

  def initialize(event, payload, options = {})
    @event = event.to_s
    @payload = payload
    @options = options
    @timestamp = Time.current
    @delivery_id = SecureRandom.uuid
  end

  def deliver
    return unless valid_event?

    webhooks = find_active_webhooks
    return if webhooks.empty?

    delivery_results = []

    webhooks.each do |webhook|
      result = deliver_to_webhook(webhook)
      delivery_results << result
      
      # Log delivery attempt
      log_delivery_attempt(webhook, result)
    end

    # Return summary
    {
      event: @event,
      delivery_id: @delivery_id,
      timestamp: @timestamp,
      webhooks_attempted: webhooks.count,
      successful_deliveries: delivery_results.count { |r| r[:success] },
      failed_deliveries: delivery_results.count { |r| !r[:success] },
      results: delivery_results
    }
  end

  private

  def valid_event?
    WEBHOOK_EVENTS.include?(@event)
  end

  def find_active_webhooks
    # This would query a WebhookEndpoint model
    # For now, return configured webhooks from options or environment
    webhooks = []
    
    # Add configured external webhooks
    if ENV['SLACK_WEBHOOK_URL'].present?
      webhooks << {
        type: 'slack',
        url: ENV['SLACK_WEBHOOK_URL'],
        events: WEBHOOK_EVENTS,
        active: true
      }
    end

    if ENV['DISCORD_WEBHOOK_URL'].present?
      webhooks << {
        type: 'discord', 
        url: ENV['DISCORD_WEBHOOK_URL'],
        events: WEBHOOK_EVENTS,
        active: true
      }
    end

    # Add Microsoft Teams webhook if configured
    if ENV['TEAMS_WEBHOOK_URL'].present?
      webhooks << {
        type: 'teams',
        url: ENV['TEAMS_WEBHOOK_URL'], 
        events: WEBHOOK_EVENTS,
        active: true
      }
    end

    # Filter by event if webhook specifies supported events
    webhooks.select { |webhook| webhook[:events].include?(@event) }
  end

  def deliver_to_webhook(webhook)
    start_time = Time.current

    begin
      # Prepare webhook payload
      webhook_payload = prepare_webhook_payload(webhook)
      
      # Make HTTP request
      response = send_webhook_request(webhook, webhook_payload)
      
      # Calculate response time
      response_time = ((Time.current - start_time) * 1000).round

      {
        webhook_id: webhook[:id] || webhook[:type],
        webhook_type: webhook[:type],
        url: webhook[:url],
        success: response.success?,
        status_code: response.code.to_i,
        response_time_ms: response_time,
        response_body: response.body,
        error: nil
      }
    rescue => error
      response_time = ((Time.current - start_time) * 1000).round
      
      {
        webhook_id: webhook[:id] || webhook[:type],
        webhook_type: webhook[:type],
        url: webhook[:url],
        success: false,
        status_code: 0,
        response_time_ms: response_time,
        response_body: nil,
        error: error.message
      }
    end
  end

  def prepare_webhook_payload(webhook)
    base_payload = {
      event: @event,
      timestamp: @timestamp.iso8601,
      delivery_id: @delivery_id,
      data: @payload
    }

    # Customize payload based on webhook type
    case webhook[:type]
    when 'slack'
      prepare_slack_payload(base_payload)
    when 'discord'
      prepare_discord_payload(base_payload)
    when 'teams'
      prepare_teams_payload(base_payload)
    else
      base_payload
    end
  end

  def prepare_slack_payload(base_payload)
    {
      text: format_event_message(@event, @payload),
      attachments: [
        {
          color: event_color(@event),
          title: "#{@event.humanize} - #{@payload[:title] || @payload[:name] || 'Festival Planner'}",
          fields: payload_fields(@payload),
          timestamp: @timestamp.to_i,
          footer: "Festival Planner Platform",
          footer_icon: "https://festival-planner.com/icon.png"
        }
      ],
      metadata: {
        event_type: @event,
        delivery_id: @delivery_id
      }
    }
  end

  def prepare_discord_payload(base_payload)
    {
      content: format_event_message(@event, @payload),
      embeds: [
        {
          title: "#{@event.humanize}",
          description: @payload[:description] || format_payload_summary(@payload),
          color: event_color_hex(@event),
          fields: payload_fields(@payload).map do |field|
            {
              name: field[:title],
              value: field[:value],
              inline: field[:short] || false
            }
          end,
          timestamp: @timestamp.iso8601,
          footer: {
            text: "Festival Planner Platform"
          }
        }
      ]
    }
  end

  def prepare_teams_payload(base_payload)
    {
      "@type" => "MessageCard",
      "@context" => "https://schema.org/extensions",
      summary: "#{@event.humanize} notification",
      themeColor: event_color_hex(@event),
      sections: [
        {
          activityTitle: "#{@event.humanize}",
          activitySubtitle: @payload[:title] || @payload[:name] || 'Festival Planner',
          activityImage: "https://festival-planner.com/icon.png",
          text: format_event_message(@event, @payload),
          facts: payload_fields(@payload).map do |field|
            {
              name: field[:title],
              value: field[:value]
            }
          end
        }
      ],
      potentialAction: potential_actions(@event, @payload)
    }
  end

  def send_webhook_request(webhook, payload)
    headers = {
      'Content-Type' => 'application/json',
      'User-Agent' => 'Festival-Planner-Platform/1.0'
    }

    # Add authentication headers if configured
    if webhook[:secret].present?
      signature = generate_signature(payload.to_json, webhook[:secret])
      headers['X-Hub-Signature-256'] = "sha256=#{signature}"
    end

    # Add custom headers for specific webhook types
    case webhook[:type]
    when 'slack'
      # Slack-specific headers
    when 'discord'
      # Discord-specific headers
    when 'teams'
      # Teams-specific headers
    end

    HTTParty.post(
      webhook[:url],
      body: payload.to_json,
      headers: headers,
      timeout: 30
    )
  end

  def format_event_message(event, payload)
    case event
    when 'task_created'
      "🆕 新しいタスクが作成されました: #{payload[:title]}"
    when 'task_completed'
      "✅ タスクが完了しました: #{payload[:title]}"
    when 'task_assigned'
      "👤 タスクが割り当てられました: #{payload[:title]} → #{payload[:assignee]}"
    when 'festival_created'
      "🎉 新しいフェスティバルが作成されました: #{payload[:name]}"
    when 'payment_confirmed'
      "💰 支払いが確認されました: #{payload[:amount]}円"
    when 'payment_failed'
      "❌ 支払いが失敗しました: #{payload[:amount]}円"
    when 'user_joined'
      "👋 新しいメンバーが参加しました: #{payload[:name]}"
    else
      "📢 #{event.humanize}: #{payload[:title] || payload[:name] || 'Update'}"
    end
  end

  def event_color(event)
    case event
    when 'task_completed', 'payment_confirmed'
      'good'
    when 'task_created', 'festival_created', 'user_joined'
      '#36a64f'
    when 'payment_failed'
      'danger'
    when 'task_assigned'
      'warning'
    else
      '#439FE0'
    end
  end

  def event_color_hex(event)
    case event
    when 'task_completed', 'payment_confirmed'
      0x36a64f
    when 'task_created', 'festival_created', 'user_joined'
      0x36a64f
    when 'payment_failed'
      0xff0000
    when 'task_assigned'
      0xffaa00
    else
      0x439fe0
    end
  end

  def payload_fields(payload)
    fields = []

    # Common fields
    fields << { title: "ID", value: payload[:id], short: true } if payload[:id]
    fields << { title: "ステータス", value: payload[:status], short: true } if payload[:status]
    fields << { title: "優先度", value: payload[:priority], short: true } if payload[:priority]
    fields << { title: "期限", value: payload[:due_date], short: true } if payload[:due_date]
    fields << { title: "担当者", value: payload[:assignee], short: true } if payload[:assignee]
    fields << { title: "フェスティバル", value: payload[:festival_name], short: true } if payload[:festival_name]
    fields << { title: "金額", value: "#{payload[:amount]}円", short: true } if payload[:amount]
    fields << { title: "説明", value: payload[:description], short: false } if payload[:description]

    fields
  end

  def format_payload_summary(payload)
    summary_parts = []
    summary_parts << "ID: #{payload[:id]}" if payload[:id]
    summary_parts << "ステータス: #{payload[:status]}" if payload[:status]
    summary_parts << "期限: #{payload[:due_date]}" if payload[:due_date]
    
    summary_parts.join(" | ")
  end

  def potential_actions(event, payload)
    actions = []

    case event
    when 'task_created', 'task_assigned'
      if payload[:task_url]
        actions << {
          "@type" => "OpenUri",
          name: "タスクを表示",
          targets: [{ os: "default", uri: payload[:task_url] }]
        }
      end
    when 'festival_created'
      if payload[:festival_url]
        actions << {
          "@type" => "OpenUri", 
          name: "フェスティバルを表示",
          targets: [{ os: "default", uri: payload[:festival_url] }]
        }
      end
    when 'payment_confirmed', 'payment_failed'
      if payload[:payment_url]
        actions << {
          "@type" => "OpenUri",
          name: "支払い詳細を表示", 
          targets: [{ os: "default", uri: payload[:payment_url] }]
        }
      end
    end

    actions
  end

  def generate_signature(payload, secret)
    OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
  end

  def log_delivery_attempt(webhook, result)
    log_data = {
      event: @event,
      delivery_id: @delivery_id,
      webhook_type: webhook[:type],
      webhook_url: webhook[:url],
      success: result[:success],
      status_code: result[:status_code],
      response_time_ms: result[:response_time_ms],
      timestamp: @timestamp
    }

    if result[:success]
      Rails.logger.info "Webhook delivery successful: #{log_data}"
    else
      Rails.logger.error "Webhook delivery failed: #{log_data.merge(error: result[:error])}"
    end

    # Store delivery log in database if webhook logging model exists
    # WebhookDeliveryLog.create!(log_data) if defined?(WebhookDeliveryLog)
  end

  # Class methods for easy event triggering
  def self.task_created(task)
    payload = {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      due_date: task.due_date&.strftime('%Y年%m月%d日'),
      assignee: task.assigned_user&.name,
      festival_name: task.festival.name,
      task_url: Rails.application.routes.url_helpers.task_url(task)
    }
    
    deliver('task_created', payload)
  end

  def self.task_completed(task)
    payload = {
      id: task.id,
      title: task.title,
      status: task.status,
      completed_by: task.completed_by&.name,
      completed_at: task.completed_at&.strftime('%Y年%m月%d日 %H:%M'),
      festival_name: task.festival.name,
      task_url: Rails.application.routes.url_helpers.task_url(task)
    }
    
    deliver('task_completed', payload)
  end

  def self.task_assigned(task, previous_assignee = nil)
    payload = {
      id: task.id,
      title: task.title,
      assignee: task.assigned_user&.name,
      previous_assignee: previous_assignee&.name,
      due_date: task.due_date&.strftime('%Y年%m月%d日'),
      priority: task.priority,
      festival_name: task.festival.name,
      task_url: Rails.application.routes.url_helpers.task_url(task)
    }
    
    deliver('task_assigned', payload)
  end

  def self.festival_created(festival)
    payload = {
      id: festival.id,
      name: festival.name,
      description: festival.description,
      start_date: festival.start_date&.strftime('%Y年%m月%d日'),
      end_date: festival.end_date&.strftime('%Y年%m月%d日'),
      location: festival.location,
      festival_url: Rails.application.routes.url_helpers.festival_url(festival)
    }
    
    deliver('festival_created', payload)
  end

  def self.payment_confirmed(payment)
    payload = {
      id: payment.id,
      amount: payment.amount,
      description: payment.description,
      payer: payment.user&.name,
      festival_name: payment.festival&.name,
      payment_url: Rails.application.routes.url_helpers.payment_url(payment)
    }
    
    deliver('payment_confirmed', payload)
  end

  def self.user_joined(user, festival)
    payload = {
      user_id: user.id,
      name: user.name,
      email: user.email,
      festival_name: festival.name,
      festival_url: Rails.application.routes.url_helpers.festival_url(festival)
    }
    
    deliver('user_joined', payload)
  end
end