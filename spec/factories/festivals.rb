FactoryBot.define do
  factory :festival do
    name { Faker::Lorem.words(number: 3).join(' ').titleize + ' Festival' }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    start_date { 1.month.from_now }
    end_date { 1.month.from_now + 3.days }
    location { Faker::Address.street_address + ', ' + Faker::Address.city }
    budget { Faker::Number.between(from: 10000, to: 200000) }
    status { :planning }
    public { false }
    association :user

    trait :summer_festival do
      name { 'Summer Festival 2025' }
      description { 'Annual summer festival in the town center' }
      start_date { 2.months.from_now }
      end_date { 2.months.from_now + 2.days }
      location { 'Town Center Park' }
      budget { 100000 }
      status { :planning }
    end

    trait :winter_festival do
      name { 'Winter Illumination' }
      description { 'Beautiful winter lights display' }
      start_date { 6.months.from_now }
      end_date { 6.months.from_now + 1.month }
      location { 'Main Street' }
      budget { 50000 }
      status { :planning }
    end

    trait :upcoming do
      start_date { 2.weeks.from_now }
      end_date { 2.weeks.from_now + 2.days }
      status { :scheduled }
    end

    trait :active do
      start_date { 1.day.ago }
      end_date { 2.days.from_now }
      status { :active }
    end

    trait :completed do
      start_date { 1.month.ago }
      end_date { 3.weeks.ago }
      status { :completed }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :public_festival do
      public { true }
    end

    trait :private_festival do
      public { false }
    end

    trait :with_capacity do
      capacity { 1000 }
    end

    trait :with_venue do
      after(:create) do |festival|
        create(:venue, festival: festival)
      end
    end

    trait :with_budget_categories do
      after(:create) do |festival|
        create_list(:budget_category, 3, festival: festival)
      end
    end

    trait :with_tasks do
      after(:create) do |festival|
        create_list(:task, 5, festival: festival)
      end
    end

    trait :with_vendor_applications do
      after(:create) do |festival|
        create_list(:vendor_application, 3, festival: festival)
      end
    end

    trait :with_payments do
      after(:create) do |festival|
        create_list(:payment, 2, festival: festival)
      end
    end

    # Simple festival for avoiding complex associations in notifications
    factory :simple_festival do
      name { 'Simple Festival' }
      description { 'Simple festival for testing' }
      start_date { 1.month.from_now }
      end_date { 1.month.from_now + 1.day }
      location { 'Test Location' }
      budget { 50000 }
      status { :planning }
      association :user
    end
  end
end
