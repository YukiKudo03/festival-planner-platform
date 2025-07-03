FactoryBot.define do
  factory :revenue do
    association :festival
    association :budget_category
    association :user
    amount { 25000.00 }
    description { 'チケット売上収入' }
    revenue_date { Date.current }
    revenue_type { 'ticket_sales' }
    status { 'pending' }

    trait :confirmed do
      status { 'confirmed' }
    end

    trait :received do
      status { 'received' }
    end

    trait :sponsorship do
      revenue_type { 'sponsorship' }
      amount { 100000.00 }
      description { 'スポンサーシップ収入' }
    end

    trait :vendor_fees do
      revenue_type { 'vendor_fees' }
      amount { 15000.00 }
      description { 'ベンダー出店料' }
    end

    trait :donation do
      revenue_type { 'donation' }
      amount { 5000.00 }
      description { '寄付収入' }
    end
  end
end
