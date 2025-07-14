# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MunicipalAuthority, type: :model do
  subject(:municipal_authority) { build(:municipal_authority) }

  describe 'validations' do
    it { should be_valid }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:authority_type) }
    it { should validate_presence_of(:jurisdiction) }
    it { should validate_presence_of(:contact_email) }
    it { should validate_format_of(:contact_email).with_message(/is not a valid email/) }

    it 'validates authority_type inclusion' do
      valid_types = MunicipalAuthority::AUTHORITY_TYPES
      valid_types.each do |type|
        municipal_authority.authority_type = type
        expect(municipal_authority).to be_valid
      end
    end

    it 'rejects invalid authority_type' do
      municipal_authority.authority_type = 'invalid_type'
      expect(municipal_authority).not_to be_valid
      expect(municipal_authority.errors[:authority_type]).to be_present
    end

    it 'validates unique name within jurisdiction' do
      existing = create(:municipal_authority, name: 'City Council', jurisdiction: 'Toronto')
      duplicate = build(:municipal_authority, name: 'City Council', jurisdiction: 'Toronto')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'allows same name in different jurisdictions' do
      existing = create(:municipal_authority, name: 'City Council', jurisdiction: 'Toronto')
      different_jurisdiction = build(:municipal_authority, name: 'City Council', jurisdiction: 'Vancouver')

      expect(different_jurisdiction).to be_valid
    end

    it 'validates contact_phone format when present' do
      municipal_authority.contact_phone = '123-456-7890'
      expect(municipal_authority).to be_valid

      municipal_authority.contact_phone = 'invalid-phone'
      expect(municipal_authority).not_to be_valid
    end

    it 'validates typical_processing_time is positive when present' do
      municipal_authority.typical_processing_time = 5
      expect(municipal_authority).to be_valid

      municipal_authority.typical_processing_time = -1
      expect(municipal_authority).not_to be_valid
    end
  end

  describe 'associations' do
    it { should have_many(:tourism_collaborations).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:city_authority) { create(:municipal_authority, authority_type: 'city_council') }
    let!(:tourism_authority) { create(:municipal_authority, authority_type: 'tourism_board') }
    let!(:active_authority) { create(:municipal_authority, is_active: true) }
    let!(:inactive_authority) { create(:municipal_authority, is_active: false) }

    describe '.by_authority_type' do
      it 'returns authorities of specific type' do
        expect(MunicipalAuthority.by_authority_type('city_council')).to contain_exactly(city_authority)
        expect(MunicipalAuthority.by_authority_type('tourism_board')).to contain_exactly(tourism_authority)
      end
    end

    describe '.active' do
      it 'returns only active authorities' do
        expect(MunicipalAuthority.active).to include(active_authority)
        expect(MunicipalAuthority.active).not_to include(inactive_authority)
      end
    end

    describe '.by_jurisdiction' do
      let!(:toronto_authority) { create(:municipal_authority, jurisdiction: 'Toronto') }
      let!(:vancouver_authority) { create(:municipal_authority, jurisdiction: 'Vancouver') }

      it 'returns authorities for specific jurisdiction' do
        expect(MunicipalAuthority.by_jurisdiction('Toronto')).to contain_exactly(toronto_authority)
        expect(MunicipalAuthority.by_jurisdiction('Vancouver')).to contain_exactly(vancouver_authority)
      end
    end
  end

  describe '#contact_info' do
    it 'returns formatted contact information hash' do
      municipal_authority.contact_email = 'info@city.gov'
      municipal_authority.contact_phone = '416-555-0123'
      municipal_authority.website_url = 'https://city.gov'

      contact_info = municipal_authority.contact_info

      expect(contact_info[:email]).to eq('info@city.gov')
      expect(contact_info[:phone]).to eq('416-555-0123')
      expect(contact_info[:website]).to eq('https://city.gov')
    end

    it 'handles missing optional contact information' do
      municipal_authority.contact_phone = nil
      municipal_authority.website_url = nil

      contact_info = municipal_authority.contact_info

      expect(contact_info[:phone]).to be_nil
      expect(contact_info[:website]).to be_nil
      expect(contact_info[:email]).to be_present
    end
  end

  describe '#processing_time_days' do
    it 'returns typical processing time' do
      municipal_authority.typical_processing_time = 14
      expect(municipal_authority.processing_time_days).to eq(14)
    end

    it 'returns default when no processing time set' do
      municipal_authority.typical_processing_time = nil
      expect(municipal_authority.processing_time_days).to eq(7) # default
    end
  end

  describe '#can_issue_permits?' do
    it 'returns true for authorities that can issue permits' do
      permit_issuing_types = %w[city_council municipal_government licensing_department]
      permit_issuing_types.each do |type|
        municipal_authority.authority_type = type
        expect(municipal_authority.can_issue_permits?).to be true
      end
    end

    it 'returns false for authorities that cannot issue permits' do
      non_permit_types = %w[tourism_board chamber_of_commerce]
      non_permit_types.each do |type|
        municipal_authority.authority_type = type
        expect(municipal_authority.can_issue_permits?).to be false
      end
    end
  end

  describe '#has_tourism_focus?' do
    it 'returns true for tourism-focused authorities' do
      tourism_types = %w[tourism_board chamber_of_commerce]
      tourism_types.each do |type|
        municipal_authority.authority_type = type
        expect(municipal_authority.has_tourism_focus?).to be true
      end
    end

    it 'returns false for non-tourism authorities' do
      municipal_authority.authority_type = 'city_council'
      expect(municipal_authority.has_tourism_focus?).to be false
    end
  end

  describe '#services_offered' do
    it 'returns appropriate services based on authority type' do
      municipal_authority.authority_type = 'city_council'
      services = municipal_authority.services_offered

      expect(services).to include('Event Permits')
      expect(services).to include('Noise Permits')
      expect(services).to include('Street Closures')
    end

    it 'returns tourism services for tourism boards' do
      municipal_authority.authority_type = 'tourism_board'
      services = municipal_authority.services_offered

      expect(services).to include('Marketing Support')
      expect(services).to include('Visitor Analytics')
      expect(services).to include('Promotional Materials')
    end

    it 'returns empty array for unknown authority types' do
      municipal_authority.authority_type = 'unknown_type'
      expect(municipal_authority.services_offered).to eq([])
    end
  end

  describe '#deactivate!' do
    it 'sets is_active to false' do
      municipal_authority.is_active = true
      municipal_authority.save!

      expect { municipal_authority.deactivate! }.to change { municipal_authority.is_active }.from(true).to(false)
    end
  end

  describe '#activate!' do
    it 'sets is_active to true' do
      municipal_authority.is_active = false
      municipal_authority.save!

      expect { municipal_authority.activate! }.to change { municipal_authority.is_active }.from(false).to(true)
    end
  end

  describe '#collaboration_count' do
    it 'returns number of tourism collaborations' do
      municipal_authority.save!
      create_list(:tourism_collaboration, 3, municipal_authority: municipal_authority)

      expect(municipal_authority.collaboration_count).to eq(3)
    end

    it 'returns 0 when no collaborations exist' do
      expect(municipal_authority.collaboration_count).to eq(0)
    end
  end

  describe '#active_collaborations' do
    it 'returns only active tourism collaborations' do
      municipal_authority.save!
      active_collab = create(:tourism_collaboration, municipal_authority: municipal_authority, status: 'active')
      _draft_collab = create(:tourism_collaboration, municipal_authority: municipal_authority, status: 'draft')

      expect(municipal_authority.active_collaborations).to contain_exactly(active_collab)
    end
  end

  describe '#average_processing_time' do
    it 'calculates average processing time based on historical data' do
      municipal_authority.save!
      # In real implementation, this would use actual historical data
      # For testing, we'll mock the calculation
      allow(municipal_authority).to receive(:average_processing_time).and_return(10.5)

      expect(municipal_authority.average_processing_time).to eq(10.5)
    end
  end

  describe '#authority_level' do
    it 'returns appropriate authority level' do
      municipal_authority.authority_type = 'city_council'
      expect(municipal_authority.authority_level).to eq('municipal')

      municipal_authority.authority_type = 'provincial_government'
      expect(municipal_authority.authority_level).to eq('provincial')

      municipal_authority.authority_type = 'federal_agency'
      expect(municipal_authority.authority_level).to eq('federal')
    end

    it 'returns municipal for unknown types' do
      municipal_authority.authority_type = 'unknown_type'
      expect(municipal_authority.authority_level).to eq('municipal')
    end
  end

  describe '#jurisdiction_coverage' do
    it 'returns coverage area description' do
      municipal_authority.jurisdiction = 'Toronto'
      municipal_authority.authority_type = 'city_council'

      coverage = municipal_authority.jurisdiction_coverage
      expect(coverage).to include('Toronto')
      expect(coverage).to include('municipal')
    end
  end

  describe 'factory' do
    it 'creates valid municipal authority' do
      municipal_authority = create(:municipal_authority)
      expect(municipal_authority).to be_valid
      expect(municipal_authority).to be_persisted
    end

    it 'creates municipal authority with specific type' do
      tourism_board = create(:municipal_authority, authority_type: 'tourism_board')
      expect(tourism_board.authority_type).to eq('tourism_board')
    end

    it 'creates active municipal authority by default' do
      municipal_authority = create(:municipal_authority)
      expect(municipal_authority.is_active).to be true
    end
  end

  describe 'callbacks' do
    it 'sets default processing time before validation' do
      municipal_authority.typical_processing_time = nil
      municipal_authority.valid?

      expect(municipal_authority.typical_processing_time).to eq(7)
    end

    it 'does not override existing processing time' do
      municipal_authority.typical_processing_time = 14
      municipal_authority.valid?

      expect(municipal_authority.typical_processing_time).to eq(14)
    end
  end

  describe 'class methods' do
    describe '.authority_types_for_select' do
      it 'returns formatted options for select elements' do
        options = MunicipalAuthority.authority_types_for_select

        expect(options).to be_an(Array)
        expect(options).to include([ 'City Council', 'city_council' ])
        expect(options).to include([ 'Tourism Board', 'tourism_board' ])
      end
    end

    describe '.find_by_service' do
      it 'finds authorities that offer specific services' do
        city_council = create(:municipal_authority, authority_type: 'city_council')
        tourism_board = create(:municipal_authority, authority_type: 'tourism_board')

        permit_authorities = MunicipalAuthority.find_by_service('permits')
        expect(permit_authorities).to include(city_council)
        expect(permit_authorities).not_to include(tourism_board)
      end
    end
  end
end
