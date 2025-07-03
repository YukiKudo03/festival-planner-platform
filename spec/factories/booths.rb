FactoryBot.define do
  factory :booth do
    venue_area { nil }
    festival { nil }
    vendor_application { nil }
    name { "MyString" }
    booth_number { "MyString" }
    size { "MyString" }
    width { "9.99" }
    height { "9.99" }
    x_position { "9.99" }
    y_position { "9.99" }
    rotation { "9.99" }
    status { "MyString" }
    power_required { false }
    water_required { false }
    special_requirements { "MyText" }
    setup_instructions { "MyText" }
  end
end
