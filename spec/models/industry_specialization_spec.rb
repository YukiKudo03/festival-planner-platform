# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IndustrySpecialization, type: :model do
  subject(:industry_specialization) { build(:industry_specialization) }

  describe 'validations' do
    it { should be_valid }
    it { should validate_presence_of(:festival) }
    it { should validate_presence_of(:industry_type) }
    it { should validate_presence_of(:specialization_config) }
    it { should validate_presence_of(:compliance_requirements) }
    it { should validate_presence_of(:specialized_metrics) }

    it 'validates industry_type inclusion' do
      valid_types = %w[technology healthcare manufacturing food_beverage arts automotive education tourism sports retail]
      valid_types.each do |type|
        industry_specialization.industry_type = type
        expect(industry_specialization).to be_valid
      end
    end

    it 'validates status inclusion' do
      valid_statuses = %w[draft active completed cancelled]
      valid_statuses.each do |status|
        industry_specialization.status = status
        expect(industry_specialization).to be_valid
      end
    end

    it 'requires valid JSON for specialization_config' do
      industry_specialization.specialization_config = 'invalid json'
      expect(industry_specialization).not_to be_valid
      expect(industry_specialization.errors[:specialization_config]).to be_present
    end

    it 'requires valid JSON for compliance_requirements' do
      industry_specialization.compliance_requirements = 'invalid json'
      expect(industry_specialization).not_to be_valid
      expect(industry_specialization.errors[:compliance_requirements]).to be_present
    end

    it 'requires valid JSON for specialized_metrics' do
      industry_specialization.specialized_metrics = 'invalid json'
      expect(industry_specialization).not_to be_valid
      expect(industry_specialization.errors[:specialized_metrics]).to be_present
    end
  end

  describe 'associations' do
    it { should belong_to(:festival) }
  end

  describe 'scopes' do
    let!(:active_specialization) { create(:industry_specialization, status: 'active') }
    let!(:draft_specialization) { create(:industry_specialization, status: 'draft') }
    let!(:completed_specialization) { create(:industry_specialization, status: 'completed') }

    describe '.active' do
      it 'returns only active specializations' do
        expect(IndustrySpecialization.active).to contain_exactly(active_specialization)
      end
    end

    describe '.by_industry_type' do
      let!(:tech_specialization) { create(:industry_specialization, industry_type: 'technology') }
      let!(:healthcare_specialization) { create(:industry_specialization, industry_type: 'healthcare') }

      it 'returns specializations for specific industry type' do
        expect(IndustrySpecialization.by_industry_type('technology')).to contain_exactly(tech_specialization)
        expect(IndustrySpecialization.by_industry_type('healthcare')).to contain_exactly(healthcare_specialization)
      end
    end
  end

  describe '#config' do
    it 'parses specialization_config as JSON' do
      config_hash = { 'booth_layout' => 'tech_standard', 'equipment_requirements' => ['wifi', 'power'] }
      industry_specialization.specialization_config = config_hash.to_json
      
      expect(industry_specialization.config).to eq(config_hash)
    end

    it 'returns empty hash if config is invalid' do
      industry_specialization.specialization_config = 'invalid json'
      expect(industry_specialization.config).to eq({})
    end
  end

  describe '#compliance' do
    it 'parses compliance_requirements as JSON' do
      compliance_hash = { 'safety_standards' => ['ISO 9001'], 'certifications' => ['FDA'] }
      industry_specialization.compliance_requirements = compliance_hash.to_json
      
      expect(industry_specialization.compliance).to eq(compliance_hash)
    end

    it 'returns empty hash if compliance is invalid' do
      industry_specialization.compliance_requirements = 'invalid json'
      expect(industry_specialization.compliance).to eq({})
    end
  end

  describe '#metrics' do
    it 'parses specialized_metrics as JSON' do
      metrics_hash = { 'kpis' => ['conversion_rate', 'lead_generation'], 'targets' => { 'leads' => 100 } }
      industry_specialization.specialized_metrics = metrics_hash.to_json
      
      expect(industry_specialization.metrics).to eq(metrics_hash)
    end

    it 'returns empty hash if metrics is invalid' do
      industry_specialization.specialized_metrics = 'invalid json'
      expect(industry_specialization.metrics).to eq({})
    end
  end

  describe '#activate!' do
    it 'changes status to active' do
      industry_specialization.status = 'draft'
      industry_specialization.save!
      
      expect { industry_specialization.activate! }.to change { industry_specialization.status }.from('draft').to('active')
    end

    it 'sets activated_at timestamp' do
      industry_specialization.activated_at = nil
      industry_specialization.save!
      
      expect { industry_specialization.activate! }.to change { industry_specialization.activated_at }.from(nil)
    end
  end

  describe '#complete!' do
    it 'changes status to completed' do
      industry_specialization.status = 'active'
      industry_specialization.save!
      
      expect { industry_specialization.complete! }.to change { industry_specialization.status }.from('active').to('completed')
    end

    it 'sets completed_at timestamp' do
      industry_specialization.completed_at = nil
      industry_specialization.save!
      
      expect { industry_specialization.complete! }.to change { industry_specialization.completed_at }.from(nil)
    end
  end

  describe '#active?' do
    it 'returns true when status is active' do
      industry_specialization.status = 'active'
      expect(industry_specialization).to be_active
    end

    it 'returns false when status is not active' do
      industry_specialization.status = 'draft'
      expect(industry_specialization).not_to be_active
    end
  end

  describe '#completed?' do
    it 'returns true when status is completed' do
      industry_specialization.status = 'completed'
      expect(industry_specialization).to be_completed
    end

    it 'returns false when status is not completed' do
      industry_specialization.status = 'active'
      expect(industry_specialization).not_to be_completed
    end
  end

  describe '#progress_percentage' do
    it 'calculates progress based on metrics completion' do
      metrics = {
        'completed_tasks' => 8,
        'total_tasks' => 10
      }
      industry_specialization.specialized_metrics = metrics.to_json
      
      expect(industry_specialization.progress_percentage).to eq(80.0)
    end

    it 'returns 0 if no metrics available' do
      industry_specialization.specialized_metrics = '{}'
      expect(industry_specialization.progress_percentage).to eq(0.0)
    end

    it 'returns 0 if total_tasks is zero' do
      metrics = { 'completed_tasks' => 0, 'total_tasks' => 0 }
      industry_specialization.specialized_metrics = metrics.to_json
      
      expect(industry_specialization.progress_percentage).to eq(0.0)
    end
  end

  describe '#compliance_score' do
    it 'calculates compliance score based on requirements' do
      compliance = {
        'requirements' => [
          { 'name' => 'ISO 9001', 'status' => 'completed' },
          { 'name' => 'FDA Approval', 'status' => 'completed' },
          { 'name' => 'Safety Cert', 'status' => 'pending' }
        ]
      }
      industry_specialization.compliance_requirements = compliance.to_json
      
      expect(industry_specialization.compliance_score).to eq(66.7)
    end

    it 'returns 100 if no requirements' do
      industry_specialization.compliance_requirements = '{"requirements": []}'
      expect(industry_specialization.compliance_score).to eq(100.0)
    end
  end

  describe '#update_metrics!' do
    it 'updates specialized metrics with new data' do
      new_metrics = { 'leads_generated' => 45, 'conversion_rate' => 12.5 }
      
      expect { industry_specialization.update_metrics!(new_metrics) }
        .to change { industry_specialization.specialized_metrics }
      
      expect(industry_specialization.metrics).to include(new_metrics.stringify_keys)
    end

    it 'merges with existing metrics' do
      existing_metrics = { 'total_leads' => 100 }
      industry_specialization.specialized_metrics = existing_metrics.to_json
      industry_specialization.save!
      
      new_metrics = { 'conversion_rate' => 15.0 }
      industry_specialization.update_metrics!(new_metrics)
      
      updated_metrics = industry_specialization.metrics
      expect(updated_metrics['total_leads']).to eq(100)
      expect(updated_metrics['conversion_rate']).to eq(15.0)
    end
  end

  describe 'factory' do
    it 'creates valid industry specialization' do
      industry_specialization = create(:industry_specialization)
      expect(industry_specialization).to be_valid
      expect(industry_specialization).to be_persisted
    end

    it 'creates industry specialization with specific industry type' do
      tech_specialization = create(:industry_specialization, industry_type: 'technology')
      expect(tech_specialization.industry_type).to eq('technology')
    end
  end

  describe 'database constraints' do
    it 'enforces uniqueness of festival and industry_type combination' do
      existing = create(:industry_specialization, industry_type: 'technology')
      duplicate = build(:industry_specialization, 
                       festival: existing.festival, 
                       industry_type: 'technology')
      
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end