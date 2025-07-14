FactoryBot.define do
  factory :notification_setting do
    # Default to first notification type to avoid conflicts
    notification_type { 'task_assigned' }
    email_enabled { true }
    web_enabled { true }
    frequency { 'immediate' }
    association :user

    trait :email_only do
      email_enabled { true }
      web_enabled { false }
    end

    trait :web_only do
      email_enabled { false }
      web_enabled { true }
    end

    trait :disabled do
      email_enabled { false }
      web_enabled { false }
      frequency { 'never' }
    end

    trait :daily_frequency do
      frequency { 'daily' }
    end

    trait :weekly_frequency do
      frequency { 'weekly' }
    end

    trait :immediate_frequency do
      frequency { 'immediate' }
    end

    trait :task_notifications do
      notification_type { 'task_deadline_reminder' }
    end

    trait :vendor_notifications do
      notification_type { 'vendor_application_submitted' }
    end

    trait :festival_notifications do
      notification_type { 'festival_created' }
    end
  end
end
