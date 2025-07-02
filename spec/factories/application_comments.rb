FactoryBot.define do
  factory :application_comment do
    vendor_application { nil }
    user { nil }
    content { "MyText" }
    internal { false }
  end
end
