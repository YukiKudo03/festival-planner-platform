FactoryBot.define do
  factory :application_comment do
    association :vendor_application
    association :user
    content { Faker::Lorem.paragraph }
    internal { false }

    trait :internal do
      internal { true }
    end

    trait :public do
      internal { false }
    end
  end
end
