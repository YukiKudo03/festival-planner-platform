FactoryBot.define do
  factory :venue do
    association :festival
    name { Faker::Lorem.words(number: 2).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    capacity { Faker::Number.between(from: 100, to: 5000) }
    address { Faker::Address.full_address }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    facility_type { Venue::FACILITY_TYPES.sample }
    contact_info { Faker::PhoneNumber.phone_number }
  end
end
