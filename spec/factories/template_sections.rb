FactoryBot.define do
  factory :template_section do
    name { Faker::Lorem.words(number: 2).join(" ") }
    description { Faker::Lorem.sentence }
    section_type { TemplateSection.section_types.keys.sample }
    position { sequence(:position) }
    required { true }
    display_conditions { {} }

    association :application_template

    trait :optional do
      required { false }
    end

    trait :information do
      section_type { :information }
      name { "基本情報" }
      description { "基本的な情報を入力してください" }
    end

    trait :business_details do
      section_type { :business_details }
      name { "事業詳細" }
      description { "事業内容の詳細を記入してください" }
    end

    trait :documents do
      section_type { :documents }
      name { "添付書類" }
      description { "必要書類をアップロードしてください" }
    end

    trait :terms_agreement do
      section_type { :terms_agreement }
      name { "規約同意" }
      description { "利用規約への同意をお願いします" }
    end

    trait :with_fields do
      after(:create) do |section|
        create_list(:template_field, 3, template_section: section)
      end
    end

    trait :with_conditional_display do
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

    trait :with_validation_rules do
      validation_rules do
        {
          "required_fields" => ["business_name", "contact_email"],
          "min_length" => {
            "description" => 100
          },
          "max_length" => {
            "description" => 1000
          }
        }
      end
    end
  end
end