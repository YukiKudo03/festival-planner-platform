FactoryBot.define do
  factory :template_field do
    name { Faker::Lorem.words(number: 2).join("_") }
    label { Faker::Lorem.words(number: 3).join(" ") }
    field_type { TemplateField.field_types.keys.sample }
    required { true }
    position { sequence(:position) }
    field_options { {} }
    validation_rules { {} }

    association :template_section

    trait :optional do
      required { false }
    end

    trait :text_field do
      field_type { :text }
      name { "business_name" }
      label { "事業者名" }
      validation_rules do
        {
          "min_length" => 2,
          "max_length" => 100,
          "pattern" => "^[\\p{L}\\p{N}\\s\\-_]+$"
        }
      end
    end

    trait :email_field do
      field_type { :email }
      name { "contact_email" }
      label { "連絡先メールアドレス" }
      validation_rules do
        {
          "format" => "email"
        }
      end
    end

    trait :select_field do
      field_type { :select }
      name { "business_type" }
      label { "事業形態" }
      field_options do
        {
          "options" => [
            { "value" => "food_service", "label" => "飲食業" },
            { "value" => "retail", "label" => "小売業" },
            { "value" => "service", "label" => "サービス業" },
            { "value" => "entertainment", "label" => "エンターテイメント" }
          ]
        }
      end
    end

    trait :textarea_field do
      field_type { :textarea }
      name { "description" }
      label { "事業内容説明" }
      field_options do
        {
          "rows" => 5,
          "placeholder" => "詳細な事業内容を記入してください"
        }
      end
      validation_rules do
        {
          "min_length" => 50,
          "max_length" => 1000
        }
      end
    end

    trait :number_field do
      field_type { :number }
      name { "expected_revenue" }
      label { "予想売上（円）" }
      validation_rules do
        {
          "min" => 0,
          "max" => 10000000
        }
      end
    end

    trait :date_field do
      field_type { :date }
      name { "preferred_date" }
      label { "希望日" }
      validation_rules do
        {
          "min_date" => "today",
          "max_date" => "+1 year"
        }
      end
    end

    trait :file_field do
      field_type { :file }
      name { "business_license" }
      label { "営業許可証" }
      field_options do
        {
          "accept" => ".pdf,.jpg,.png",
          "max_size" => "5MB",
          "multiple" => false
        }
      end
    end

    trait :checkbox_field do
      field_type { :checkbox }
      name { "terms_agreement" }
      label { "利用規約に同意する" }
      validation_rules do
        {
          "required" => true
        }
      end
    end

    trait :radio_field do
      field_type { :radio }
      name { "booth_size" }
      label { "ブースサイズ" }
      field_options do
        {
          "options" => [
            { "value" => "small", "label" => "小（3m×3m）" },
            { "value" => "medium", "label" => "中（6m×3m）" },
            { "value" => "large", "label" => "大（6m×6m）" }
          ]
        }
      end
    end

    trait :phone_field do
      field_type { :tel }
      name { "contact_phone" }
      label { "連絡先電話番号" }
      validation_rules do
        {
          "pattern" => "^[0-9\\-+()\\s]+$",
          "min_length" => 10,
          "max_length" => 15
        }
      end
    end

    trait :url_field do
      field_type { :url }
      name { "website_url" }
      label { "ウェブサイトURL" }
      validation_rules do
        {
          "format" => "url"
        }
      end
    end

    trait :with_help_text do
      help_text { "この項目について詳しい説明やヒントをここに記載します" }
    end

    trait :with_default_value do
      default_value { "デフォルト値" }
    end

    trait :with_conditional_logic do
      display_conditions do
        {
          "show_when" => {
            "field_name" => "business_type",
            "operator" => "equals",
            "value" => "food_service"
          }
        }
      end
    end
  end
end