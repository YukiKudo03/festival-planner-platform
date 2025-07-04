FactoryBot.define do
  factory :payment do
    festival { nil }
    user { nil }
    amount { "9.99" }
    payment_method { "MyString" }
    status { "MyString" }
    currency { "MyString" }
    description { "MyText" }
    customer_email { "MyString" }
    customer_name { "MyString" }
    billing_address { "MyText" }
    external_transaction_id { "MyString" }
    processing_fee { "9.99" }
    metadata { "" }
    processed_at { "2025-07-04 21:19:04" }
    confirmed_at { "2025-07-04 21:19:04" }
    cancelled_at { "2025-07-04 21:19:04" }
    cancellation_reason { "MyText" }
    error_message { "MyText" }
  end
end
