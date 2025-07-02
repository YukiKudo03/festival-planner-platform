FactoryBot.define do
  factory :chat_message do
    chat_room { nil }
    user { nil }
    content { "MyText" }
    message_type { "MyString" }
  end
end
