FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { :resident }

    trait :admin do
      role { :admin }
      email { Faker::Internet.unique.email }
      first_name { 'Admin' }
      last_name { 'User' }
    end

    trait :committee_member do
      role { :committee_member }
      email { Faker::Internet.unique.email }
      first_name { 'Committee' }
      last_name { 'Member' }
    end

    trait :vendor do
      role { :vendor }
      email { Faker::Internet.unique.email }
      first_name { 'Vendor' }
      last_name { 'User' }
    end

    trait :volunteer do
      role { :volunteer }
      email { Faker::Internet.unique.email }
      first_name { 'Volunteer' }
      last_name { 'User' }
    end

    trait :resident do
      role { :resident }
      email { Faker::Internet.unique.email }
      first_name { 'Resident' }
      last_name { 'User' }
    end

    trait :platform_visitor do
      role { :platform_visitor }
      email { Faker::Internet.unique.email }
      first_name { 'Platform' }
      last_name { 'Visitor' }
    end

    trait :system_admin do
      role { :system_admin }
      email { Faker::Internet.unique.email }
      first_name { 'System' }
      last_name { 'Admin' }
    end
  end
end
