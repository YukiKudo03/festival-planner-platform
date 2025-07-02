FactoryBot.define do
  factory :reaction do
    reactable { nil }
    user { nil }
    reaction_type { "MyString" }
  end
end
