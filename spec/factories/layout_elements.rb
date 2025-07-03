FactoryBot.define do
  factory :layout_element do
    venue { nil }
    element_type { "MyString" }
    name { "MyString" }
    description { "MyText" }
    x_position { "9.99" }
    y_position { "9.99" }
    width { "9.99" }
    height { "9.99" }
    rotation { "9.99" }
    color { "MyString" }
    properties { "MyText" }
    layer { 1 }
    locked { false }
    visible { false }
  end
end
