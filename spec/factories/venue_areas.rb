FactoryBot.define do
  factory :venue_area do
    venue { nil }
    name { "MyString" }
    description { "MyText" }
    area_type { "MyString" }
    width { "9.99" }
    height { "9.99" }
    x_position { "9.99" }
    y_position { "9.99" }
    rotation { "9.99" }
    color { "MyString" }
    capacity { 1 }
  end
end
