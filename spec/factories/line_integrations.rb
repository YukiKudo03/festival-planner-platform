FactoryBot.define do
  factory :line_integration do
    association :festival
    association :user

    sequence(:line_channel_id) { |n| "123456789#{n}" }
    line_channel_secret { "channel_secret_#{SecureRandom.hex(10)}" }
    line_access_token { "access_token_#{SecureRandom.hex(20)}" }
    webhook_url { "https://example.com/webhooks/line/#{SecureRandom.hex(8)}" }
    is_active { true }
    status { :active }

    settings do
      {
        'auto_task_creation' => true,
        'task_reminder_enabled' => true,
        'group_sync_interval' => 30,
        'message_parsing_enabled' => true,
        'debug_mode' => false,
        'webhook_signature_verification' => true,
        'allowed_message_types' => [ 'text', 'sticker' ],
        'task_keywords' => [ 'タスク', 'TODO', '作業' ],
        'priority_keywords' => {
          'high' => [ '緊急', '至急', '重要' ],
          'medium' => [ '普通', '通常' ],
          'low' => [ '後で', '低優先' ]
        }
      }
    end

    notification_preferences do
      {
        'task_created' => true,
        'task_assigned' => true,
        'task_completed' => true,
        'task_overdue' => true,
        'deadline_reminder' => true,
        'festival_updates' => true,
        'system_notifications' => false,
        'notification_times' => {
          'start' => '09:00',
          'end' => '18:00'
        },
        'quiet_hours_enabled' => true,
        'mention_only' => false
      }
    end

    last_sync_at { 1.hour.ago }
    last_webhook_received_at { 30.minutes.ago }

    trait :inactive do
      is_active { false }
      status { :inactive }
    end

    trait :error_status do
      status { :error }
      last_error_message { "API connection failed" }
      last_error_at { 1.hour.ago }
    end

    trait :suspended do
      status { :suspended }
      is_active { false }
    end

    trait :without_webhook do
      webhook_url { nil }
    end

    trait :with_recent_activity do
      last_webhook_received_at { 5.minutes.ago }
      last_sync_at { 10.minutes.ago }
    end
  end
end
