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
      email { 'admin@test.com' }
      first_name { 'Admin' }
      last_name { 'User' }
    end

    trait :committee_member do
      role { :committee_member }
      email { 'committee@test.com' }
      first_name { 'Committee' }
      last_name { 'Member' }
    end

    trait :vendor do
      role { :vendor }
      email { 'vendor@test.com' }
      first_name { 'Vendor' }
      last_name { 'User' }
    end

    trait :volunteer do
      role { :volunteer }
      email { 'volunteer@test.com' }
      first_name { 'Volunteer' }
      last_name { 'User' }
    end

    trait :resident do
      role { :resident }
      email { 'resident@test.com' }
      first_name { 'Resident' }
      last_name { 'User' }
    end

    trait :platform_visitor do
      role { :platform_visitor }
      email { 'visitor@test.com' }
      first_name { 'Platform' }
      last_name { 'Visitor' }
    end

    trait :system_admin do
      role { :system_admin }
      email { 'system_admin@test.com' }
      first_name { 'System' }
      last_name { 'Admin' }
    end
  end
end