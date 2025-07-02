FactoryBot.define do
  factory :chat_room do
    name { "MyString" }
    description { "MyText" }
    room_type { "MyString" }
    festival { nil }
    private { false }
  end
end
