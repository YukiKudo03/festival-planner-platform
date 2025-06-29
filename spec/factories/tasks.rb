FactoryBot.define do
  factory :task do
    title { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph }
    due_date { 1.month.from_now }
    priority { [:low, :medium, :high].sample }
    status { :pending }
    association :user
    association :festival

    trait :venue_booking do
      title { 'Book venue for summer festival' }
      description { 'Contact town hall for venue reservation' }
      due_date { 1.month.from_now }
      priority { :high }
      status { :pending }
    end

    trait :sponsor_contact do
      title { 'Contact potential sponsors' }
      description { 'Reach out to local businesses for sponsorship' }
      due_date { 3.weeks.from_now }
      priority { :medium }
      status { :pending }
      association :user
    end

    trait :high_priority do
      priority { :high }
    end

    trait :medium_priority do
      priority { :medium }
    end

    trait :low_priority do
      priority { :low }
    end

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
    end

    trait :overdue do
      due_date { 1.week.ago }
      status { :pending }
    end
  end
end