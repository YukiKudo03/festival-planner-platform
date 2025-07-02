FactoryBot.define do
  factory :chat_room_member do
    chat_room { nil }
    user { nil }
    role { "MyString" }
    joined_at { "2025-07-02 20:20:39" }
    last_read_at { "2025-07-02 20:20:39" }
  end
end
