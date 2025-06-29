FactoryBot.define do
  factory :vendor_application do
    business_name { Faker::Company.name }
    business_type { ['Food Service', 'Handicrafts', 'Entertainment', 'Retail'].sample }
    description { Faker::Lorem.paragraph }
    requirements { Faker::Lorem.sentence }
    status { :pending }
    association :festival
    association :user

    trait :food_truck do
      business_name { 'Tasty Food Truck' }
      business_type { 'Food Service' }
      description { 'Authentic street food and beverages' }
      requirements { 'Electrical outlet, water access' }
      status { :pending }
    end

    trait :craft_booth do
      business_name { 'Local Crafts' }
      business_type { 'Handicrafts' }
      description { 'Handmade local crafts and souvenirs' }
      requirements { 'Covered area, tables' }
      status { :pending }
      association :user
    end

    trait :pending do
      status { :pending }
    end

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :with_contact_info do
      # Contact info comes from the associated user
    end
  end
end