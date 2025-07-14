FactoryBot.define do
  factory :line_message do
    association :line_group
    task { nil }

    line_message_id { "#{SecureRandom.hex(8)}-#{SecureRandom.hex(8)}" }
    sender_line_user_id { "U#{SecureRandom.hex(16)}" }
    message_type { 'text' }
    message_text { "テストメッセージ内容 #{SecureRandom.hex(4)}" }
    line_timestamp { rand(1..120).minutes.ago }
    is_processed { false }

    raw_data do
      {
        'type' => message_type,
        'id' => line_message_id,
        'text' => message_text,
        'source' => {
          'type' => 'group',
          'groupId' => line_group.line_group_id,
          'userId' => sender_line_user_id
        },
        'timestamp' => (line_timestamp.to_f * 1000).to_i,
        'mode' => 'active',
        'webhookEventId' => SecureRandom.hex(16),
        'deliveryContext' => {
          'isRedelivery' => false
        }
      }
    end

    processing_result do
      {
        'processed_at' => nil,
        'task_created' => false,
        'parsing_errors' => [],
        'confidence_score' => nil
      }
    end

    trait :processed do
      is_processed { true }
      processing_result do
        {
          'processed_at' => 30.minutes.ago.iso8601,
          'task_created' => true,
          'parsing_errors' => [],
          'confidence_score' => 0.85
        }
      end
    end

    trait :with_task do
      association :task, factory: :task
      is_processed { true }
      processing_result do
        {
          'processed_at' => 30.minutes.ago.iso8601,
          'task_created' => true,
          'parsing_errors' => [],
          'confidence_score' => 0.90
        }
      end
    end

    trait :processing_failed do
      is_processed { true }
      processing_result do
        {
          'processed_at' => 30.minutes.ago.iso8601,
          'task_created' => false,
          'parsing_errors' => [ 'Failed to parse task content', 'Invalid priority level' ],
          'confidence_score' => 0.20
        }
      end
    end

    trait :sticker_message do
      message_type { 'sticker' }
      message_text { nil }
      raw_data do
        {
          'type' => 'sticker',
          'id' => line_message_id,
          'stickerId' => '1',
          'packageId' => '1',
          'source' => {
            'type' => 'group',
            'groupId' => line_group.line_group_id,
            'userId' => sender_line_user_id
          },
          'timestamp' => (line_timestamp.to_f * 1000).to_i
        }
      end
    end

    trait :image_message do
      message_type { 'image' }
      message_text { nil }
      raw_data do
        {
          'type' => 'image',
          'id' => line_message_id,
          'contentProvider' => {
            'type' => 'line'
          },
          'source' => {
            'type' => 'group',
            'groupId' => line_group.line_group_id,
            'userId' => sender_line_user_id
          },
          'timestamp' => (line_timestamp.to_f * 1000).to_i
        }
      end
    end

    trait :task_creation_message do
      message_text { "新しいタスク: #{FFaker::Lorem.sentence}" }
      raw_data do
        {
          'type' => 'text',
          'id' => line_message_id,
          'text' => message_text,
          'source' => {
            'type' => 'group',
            'groupId' => line_group.line_group_id,
            'userId' => sender_line_user_id
          },
          'timestamp' => (line_timestamp.to_f * 1000).to_i
        }
      end
    end

    trait :high_priority_message do
      message_text { "緊急タスク: #{FFaker::Lorem.sentence}" }
    end

    trait :low_priority_message do
      message_text { "後でやる: #{FFaker::Lorem.sentence}" }
    end

    trait :recent do
      line_timestamp { 5.minutes.ago }
    end

    trait :old do
      line_timestamp { 2.days.ago }
    end
  end
end
