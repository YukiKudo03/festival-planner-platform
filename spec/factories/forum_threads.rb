FactoryBot.define do
  factory :forum_thread do
    forum { nil }
    user { nil }
    title { "MyString" }
    content { "MyText" }
    pinned { false }
    locked { false }
  end
end
