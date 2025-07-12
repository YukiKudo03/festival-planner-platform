# frozen_string_literal: true

FactoryBot.define do
  factory :municipal_authority do
    name { "#{jurisdiction} #{authority_type.humanize}" }
    authority_type { MunicipalAuthority::AUTHORITY_TYPES.sample }
    jurisdiction { Faker::Address.city }
    contact_email { Faker::Internet.email }
    contact_phone { Faker::PhoneNumber.phone_number }
    website_url { "https://#{jurisdiction.downcase.gsub(' ', '')}.gov" }
    typical_processing_time { rand(3..21) }
    is_active { true }
    api_endpoint { "https://api.#{jurisdiction.downcase.gsub(' ', '')}.gov/v1" }
    api_key { SecureRandom.hex(16) }
    
    trait :city_council do
      authority_type { 'city_council' }
      name { "#{jurisdiction} City Council" }
      typical_processing_time { rand(7..14) }
    end
    
    trait :tourism_board do
      authority_type { 'tourism_board' }
      name { "#{jurisdiction} Tourism Board" }
      typical_processing_time { rand(3..7) }
      website_url { "https://visit#{jurisdiction.downcase.gsub(' ', '')}.com" }
    end
    
    trait :municipal_government do
      authority_type { 'municipal_government' }
      name { "Municipality of #{jurisdiction}" }
      typical_processing_time { rand(10..21) }
    end
    
    trait :licensing_department do
      authority_type { 'licensing_department' }
      name { "#{jurisdiction} Licensing Department" }
      typical_processing_time { rand(5..10) }
    end
    
    trait :chamber_of_commerce do
      authority_type { 'chamber_of_commerce' }
      name { "#{jurisdiction} Chamber of Commerce" }
      typical_processing_time { rand(3..5) }
      website_url { "https://#{jurisdiction.downcase.gsub(' ', '')}chamber.org" }
    end
    
    trait :provincial_government do
      authority_type { 'provincial_government' }
      name { "Province of #{jurisdiction}" }
      jurisdiction { Faker::Address.state }
      typical_processing_time { rand(14..28) }
    end
    
    trait :federal_agency do
      authority_type { 'federal_agency' }
      name { "Federal #{jurisdiction} Agency" }
      jurisdiction { 'Canada' }
      typical_processing_time { rand(21..42) }
    end
    
    trait :inactive do
      is_active { false }
    end
    
    trait :fast_processing do
      typical_processing_time { rand(1..3) }
    end
    
    trait :slow_processing do
      typical_processing_time { rand(21..45) }
    end
    
    trait :with_api_integration do
      api_endpoint { "https://api.#{jurisdiction.downcase.gsub(' ', '')}.gov/v1" }
      api_key { SecureRandom.hex(16) }
    end
    
    trait :without_api_integration do
      api_endpoint { nil }
      api_key { nil }
    end
    
    # Preset authorities for common scenarios
    trait :toronto_city_council do
      name { 'Toronto City Council' }
      authority_type { 'city_council' }
      jurisdiction { 'Toronto' }
      contact_email { 'council@toronto.ca' }
      contact_phone { '416-392-7885' }
      website_url { 'https://www.toronto.ca' }
      typical_processing_time { 14 }
    end
    
    trait :vancouver_tourism do
      name { 'Tourism Vancouver' }
      authority_type { 'tourism_board' }
      jurisdiction { 'Vancouver' }
      contact_email { 'info@tourismvancouver.com' }
      contact_phone { '604-682-2222' }
      website_url { 'https://www.tourismvancouver.com' }
      typical_processing_time { 5 }
    end
    
    trait :montreal_licensing do
      name { 'Montreal Licensing Department' }
      authority_type { 'licensing_department' }
      jurisdiction { 'Montreal' }
      contact_email { 'licenses@montreal.ca' }
      contact_phone { '514-872-3111' }
      website_url { 'https://montreal.ca/en/services/permits-and-licenses' }
      typical_processing_time { 7 }
    end
    
    trait :ontario_provincial do
      name { 'Province of Ontario' }
      authority_type { 'provincial_government' }
      jurisdiction { 'Ontario' }
      contact_email { 'info@ontario.ca' }
      contact_phone { '416-325-1234' }
      website_url { 'https://www.ontario.ca' }
      typical_processing_time { 21 }
    end
    
    # Dynamic jurisdictions based on major Canadian cities
    trait :major_city do
      jurisdiction { ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa', 'Edmonton', 'Winnipeg', 'Quebec City'].sample }
    end
    
    # Authority with comprehensive contact information
    trait :comprehensive_contact do
      contact_phone { '+1-' + Faker::PhoneNumber.phone_number }
      website_url { "https://#{name.downcase.gsub(' ', '-')}.gov" }
      
      after(:build) do |authority|
        # Add realistic email based on authority type and jurisdiction
        domain = case authority.authority_type
                when 'tourism_board'
                  "visit#{authority.jurisdiction.downcase.gsub(' ', '')}.com"
                when 'chamber_of_commerce'
                  "#{authority.jurisdiction.downcase.gsub(' ', '')}chamber.org"
                else
                  "#{authority.jurisdiction.downcase.gsub(' ', '')}.gov"
                end
        authority.contact_email = "info@#{domain}"
      end
    end
    
    # Authority with realistic processing times based on type
    trait :realistic_processing_times do
      after(:build) do |authority|
        authority.typical_processing_time = case authority.authority_type
                                          when 'tourism_board', 'chamber_of_commerce'
                                            rand(3..7)
                                          when 'licensing_department'
                                            rand(5..10)
                                          when 'city_council', 'municipal_government'
                                            rand(7..14)
                                          when 'provincial_government'
                                            rand(14..28)
                                          when 'federal_agency'
                                            rand(21..42)
                                          else
                                            rand(7..14)
                                          end
      end
    end
    
    # Authority with tourism collaborations
    trait :with_tourism_collaborations do
      after(:create) do |authority|
        create_list(:tourism_collaboration, rand(1..3), municipal_authority: authority)
      end
    end
    
    # Authority with active tourism collaborations
    trait :with_active_collaborations do
      after(:create) do |authority|
        create_list(:tourism_collaboration, rand(1..2), :active, municipal_authority: authority)
      end
    end
    
    # Authority type variations with specific configurations
    transient do
      authority_config { {} }
    end
    
    after(:build) do |authority, evaluator|
      # Apply authority-specific configurations
      case authority.authority_type
      when 'tourism_board'
        authority.name = "#{authority.jurisdiction} Tourism Board" if authority.name.blank?
        authority.website_url = "https://visit#{authority.jurisdiction.downcase.gsub(' ', '')}.com" if authority.website_url.blank?
      when 'chamber_of_commerce'
        authority.name = "#{authority.jurisdiction} Chamber of Commerce" if authority.name.blank?
        authority.website_url = "https://#{authority.jurisdiction.downcase.gsub(' ', '')}chamber.org" if authority.website_url.blank?
      when 'city_council'
        authority.name = "#{authority.jurisdiction} City Council" if authority.name.blank?
      when 'municipal_government'
        authority.name = "Municipality of #{authority.jurisdiction}" if authority.name.blank?
      when 'licensing_department'
        authority.name = "#{authority.jurisdiction} Licensing Department" if authority.name.blank?
      end
      
      # Apply any custom configurations
      evaluator.authority_config.each do |key, value|
        authority.send("#{key}=", value) if authority.respond_to?("#{key}=")
      end
    end
    
    # Ensure unique combinations
    after(:build) do |authority|
      counter = 1
      original_name = authority.name
      
      while MunicipalAuthority.exists?(name: authority.name, jurisdiction: authority.jurisdiction)
        authority.name = "#{original_name} #{counter}"
        counter += 1
      end
    end
  end
end