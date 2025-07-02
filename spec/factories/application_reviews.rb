FactoryBot.define do
  factory :application_review do
    vendor_application { nil }
    reviewer { nil }
    action { 1 }
    comment { "MyText" }
    conditions { "MyText" }
    reviewed_at { "2025-06-30 08:17:52" }
  end
end
