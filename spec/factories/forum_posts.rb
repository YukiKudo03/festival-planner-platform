FactoryBot.define do
  factory :forum_post do
    forum_thread { nil }
    user { nil }
    content { "MyText" }
  end
end
