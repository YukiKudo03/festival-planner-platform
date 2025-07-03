FactoryBot.define do
  factory :budget_category do
    association :festival
    name { '会場費' }
    description { '会場使用料、設営費用など' }
    parent { nil }
    budget_limit { 100000.00 }
  end
end
