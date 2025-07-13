FactoryBot.define do
  factory :line_group do
    association :line_integration
    
    line_group_id { "G#{SecureRandom.hex(16)}" }
    name { "テストグループ #{SecureRandom.hex(4)}" }
    member_count { rand(3..15) }
    is_active { true }
    last_activity_at { rand(1..24).hours.ago }
    
    group_settings do
      {
        task_creation_enabled: true,
        notifications_enabled: true,
        auto_parse_enabled: true,
        require_keywords: false,
        allowed_users: [],
        restricted_mode: false,
        task_assignment_mode: 'auto',
        default_task_priority: 'medium',
        notification_format: 'standard',
        quiet_hours: {
          enabled: true,
          start: '22:00',
          end: '08:00'
        },
        keywords: {
          task_triggers: ['タスク', 'TODO', '作業', 'やること'],
          priority_high: ['緊急', '至急', '重要'],
          priority_low: ['後で', '時間があるとき']
        }
      }
    end
    
    trait :inactive do
      is_active { false }
    end
    
    trait :recent_activity do
      last_activity_at { 5.minutes.ago }
    end
    
    trait :old_activity do
      last_activity_at { 3.days.ago }
    end
    
    trait :small_group do
      member_count { rand(2..5) }
    end
    
    trait :large_group do
      member_count { rand(20..50) }
    end
    
    trait :task_creation_disabled do
      group_settings do
        {
          task_creation_enabled: false,
          notifications_enabled: true,
          auto_parse_enabled: false
        }
      end
    end
    
    trait :notifications_disabled do
      group_settings do
        {
          task_creation_enabled: true,
          notifications_enabled: false,
          auto_parse_enabled: true
        }
      end
    end
    
    trait :restricted_mode do
      group_settings do
        {
          task_creation_enabled: true,
          notifications_enabled: true,
          auto_parse_enabled: true,
          restricted_mode: true,
          allowed_users: ['U1234567890', 'U0987654321']
        }
      end
    end
  end
end