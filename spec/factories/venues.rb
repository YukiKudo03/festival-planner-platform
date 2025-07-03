FactoryBot.define do
  factory :venue do
    festival { nil }
    name { "MyString" }
    description { "MyText" }
    capacity { 1 }
    address { "MyText" }
    latitude { "9.99" }
    longitude { "9.99" }
    facility_type { "MyString" }
    contact_info { "MyText" }
  end
end
