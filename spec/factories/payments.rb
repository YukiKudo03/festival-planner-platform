FactoryBot.define do
  factory :payment do
    association :festival
    association :user
    amount { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    payment_method { :stripe }
    status { :pending }
    currency { 'JPY' }
    description { Faker::Lorem.sentence }
    customer_email { user&.email || Faker::Internet.email }
    customer_name { user&.full_name || Faker::Name.name }
    processing_fee { (amount * 0.03).round(2) }

    trait :with_stripe do
      payment_method { :stripe }
      external_transaction_id { "pi_#{Faker::Alphanumeric.alphanumeric(number: 24)}" }
      metadata do
        {
          checkout_url: "https://checkout.stripe.com/session_#{Faker::Alphanumeric.alphanumeric(number: 24)}",
          payment_intent_id: "pi_#{Faker::Alphanumeric.alphanumeric(number: 24)}"
        }
      end
    end

    trait :with_paypal do
      payment_method { :paypal }
      external_transaction_id { Faker::Alphanumeric.alphanumeric(number: 17).upcase }
      metadata do
        {
          redirect_url: "https://www.paypal.com/checkoutnow?token=#{Faker::Alphanumeric.alphanumeric(number: 20)}"
        }
      end
    end

    trait :with_bank_transfer do
      payment_method { :bank_transfer }
      metadata do
        {
          instructions: {
            bank_name: '三菱UFJ銀行',
            branch_name: '渋谷支店',
            account_type: '普通',
            account_number: '1234567',
            account_holder: 'フェスティバル プラットフォーム カブシキガイシャ'
          }
        }
      end
    end

    trait :with_cash do
      payment_method { :cash }
      metadata do
        {
          instructions: {
            location: 'フェスティバル会場受付',
            hours: '10:00-18:00',
            contact: '090-1234-5678'
          }
        }
      end
    end

    trait :pending do
      status { :pending }
    end

    trait :processing do
      status { :processing }
      processed_at { 5.minutes.ago }
    end

    trait :completed do
      status { :completed }
      processed_at { 1.hour.ago }
      confirmed_at { 30.minutes.ago }
    end

    trait :failed do
      status { :failed }
      processed_at { 30.minutes.ago }
      error_message { 'カードが拒否されました' }
    end

    trait :cancelled do
      status { :cancelled }
      cancelled_at { 15.minutes.ago }
      cancellation_reason { 'ユーザーによりキャンセル' }
    end

    trait :refunded do
      status { :refunded }
      processed_at { 2.hours.ago }
      confirmed_at { 1.hour.ago }
    end

    trait :high_amount do
      amount { Faker::Number.between(from: 50000, to: 200000) }
    end

    trait :low_amount do
      amount { Faker::Number.between(from: 1000, to: 5000) }
    end

    trait :with_billing_address do
      billing_address do
        {
          name: customer_name,
          line1: Faker::Address.street_address,
          city: Faker::Address.city,
          state: Faker::Address.state,
          postal_code: Faker::Address.zip_code,
          country: 'JP'
        }.to_json
      end
    end
  end
end
