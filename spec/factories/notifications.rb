FactoryBot.define do
  factory :notification do
    title { Faker::Lorem.sentence }
    message { Faker::Lorem.paragraph }
    notification_type { Notification::NOTIFICATION_TYPES.sample }
    read_at { nil }
    sent_at { Time.current }
    association :recipient, factory: :user
    association :sender, factory: :user
    association :notifiable, factory: :task

    trait :unread do
      read_at { nil }
    end

    trait :read do
      read_at { 1.hour.ago }
    end

    trait :task_deadline_reminder do
      notification_type { 'task_deadline_reminder' }
      title { 'タスクの期限が近づいています' }
      message { 'タスクの期限が近づいています。確認をお願いします。' }
    end

    trait :task_overdue do
      notification_type { 'task_overdue' }
      title { 'タスクが期限切れになりました' }
      message { 'タスクが期限切れになりました。確認をお願いします。' }
    end

    trait :task_assigned do
      notification_type { 'task_assigned' }
      title { '新しいタスクが割り当てられました' }
      message { '新しいタスクが割り当てられました。' }
    end

    trait :vendor_application_submitted do
      notification_type { 'vendor_application_submitted' }
      title { '新しい出店申請が提出されました' }
      message { '新しい出店申請が提出されました。' }
    end

    trait :vendor_application_approved do
      notification_type { 'vendor_application_approved' }
      title { '出店申請が承認されました' }
      message { '出店申請が承認されました。おめでとうございます！' }
    end

    trait :festival_created do
      notification_type { 'festival_created' }
      title { '新しいお祭りが企画されました' }
      message { '新しいお祭りが企画されました。詳細をご確認ください。' }
    end

    trait :system_announcement do
      notification_type { 'system_announcement' }
      title { 'システムからのお知らせ' }
      message { 'システムからの重要なお知らせです。' }
      sender { nil }
      notifiable { nil }
    end
  end
end