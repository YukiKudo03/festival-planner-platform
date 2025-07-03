FactoryBot.define do
  factory :expense do
    association :festival
    association :budget_category
    association :user
    amount { 15000.00 }
    description { '会場設営費用' }
    expense_date { Date.current }
    payment_method { 'cash' }
    status { 'draft' }

    trait :pending do
      status { 'pending' }
    end

    trait :approved do
      status { 'approved' }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :credit_card do
      payment_method { 'credit_card' }
    end
  end
end
