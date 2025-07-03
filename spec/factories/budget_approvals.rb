FactoryBot.define do
  factory :budget_approval do
    association :festival
    association :budget_category
    association :approver, factory: :user
    requested_amount { 50000.00 }
    approved_amount { 50000.00 }
    status { 'pending' }
    notes { '予算承認申請' }

    trait :approved do
      status { 'approved' }
    end

    trait :rejected do
      status { 'rejected' }
      approved_amount { 0 }
      notes { '予算不足のため却下' }
    end
  end
end
