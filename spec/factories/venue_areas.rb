FactoryBot.define do
  factory :venue_area do
    association :venue
    name { Faker::Lorem.words(number: 2).join(' ').titleize }
    description { Faker::Lorem.sentence }
    area_type { VenueArea::AREA_TYPES.sample }
    width { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    height { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    x_position { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    y_position { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    rotation { Faker::Number.between(from: 0, to: 360) }
    color { Faker::Color.hex_color }
    capacity { Faker::Number.between(from: 10, to: 500) }
  end
end
