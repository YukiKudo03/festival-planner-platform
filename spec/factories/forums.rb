FactoryBot.define do
  factory :forum do
    festival { nil }
    name { "MyString" }
    description { "MyText" }
    category { "MyString" }
    private { false }
  end
end
