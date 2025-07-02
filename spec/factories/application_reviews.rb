FactoryBot.define do
  factory :application_review do
    association :vendor_application
    association :reviewer, factory: :user
    action { :submitted }
    comment { Faker::Lorem.paragraph }
    conditions { nil }
    reviewed_at { Time.current }

    trait :approved do
      action { :approved }
      comment { "承認いたします。" }
    end

    trait :rejected do
      action { :rejected }
      comment { "申し訳ございませんが、却下いたします。" }
    end

    trait :requested_changes do
      action { :requested_changes }
      comment { "以下の点について修正をお願いします。" }
    end

    trait :conditionally_approved do
      action { :conditionally_approved }
      comment { "条件付きで承認いたします。" }
      conditions { "指定された条件を満たすこと" }
    end
  end
end
