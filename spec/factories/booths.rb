FactoryBot.define do
  factory :booth do
    association :venue_area
    association :festival
    vendor_application { nil }
    name { Faker::Lorem.words(number: 2).join(' ').titleize }
    sequence(:booth_number) { |n| "BOOTH-#{n.to_s.rjust(3, '0')}" }
    size { Booth::SIZES.sample }
    width { Faker::Number.decimal(l_digits: 1, r_digits: 2) }
    height { Faker::Number.decimal(l_digits: 1, r_digits: 2) }
    x_position { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    y_position { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    rotation { Faker::Number.between(from: 0, to: 360) }
    status { Booth::STATUSES.sample }
    power_required { Faker::Boolean.boolean }
    water_required { Faker::Boolean.boolean }
    special_requirements { Faker::Lorem.sentence }
    setup_instructions { Faker::Lorem.paragraph }
  end
end
