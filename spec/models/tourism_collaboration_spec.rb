# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TourismCollaboration, type: :model do
  subject(:tourism_collaboration) { build(:tourism_collaboration) }

  describe 'validations' do
    it { should be_valid }
    it { should validate_presence_of(:festival) }
    it { should validate_presence_of(:municipal_authority) }
    it { should validate_presence_of(:collaboration_type) }
    it { should validate_presence_of(:partnership_details) }
    it { should validate_presence_of(:marketing_campaigns) }

    it 'validates collaboration_type inclusion' do
      valid_types = %w[tourism_board government_liaison economic_development marketing_partnership permit_assistance]
      valid_types.each do |type|
        tourism_collaboration.collaboration_type = type
        expect(tourism_collaboration).to be_valid
      end
    end

    it 'validates status inclusion' do
      valid_statuses = %w[draft proposed approved active completed cancelled]
      valid_statuses.each do |status|
        tourism_collaboration.status = status
        expect(tourism_collaboration).to be_valid
      end
    end

    it 'requires valid JSON for partnership_details' do
      tourism_collaboration.partnership_details = 'invalid json'
      expect(tourism_collaboration).not_to be_valid
      expect(tourism_collaboration.errors[:partnership_details]).to be_present
    end

    it 'requires valid JSON for marketing_campaigns' do
      tourism_collaboration.marketing_campaigns = 'invalid json'
      expect(tourism_collaboration).not_to be_valid
      expect(tourism_collaboration.errors[:marketing_campaigns]).to be_present
    end

    it 'requires valid JSON for visitor_analytics' do
      tourism_collaboration.visitor_analytics = 'invalid json'
      expect(tourism_collaboration).not_to be_valid
      expect(tourism_collaboration.errors[:visitor_analytics]).to be_present
    end
  end

  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:municipal_authority) }
  end

  describe 'scopes' do
    let!(:active_collaboration) { create(:tourism_collaboration, status: 'active') }
    let!(:proposed_collaboration) { create(:tourism_collaboration, status: 'proposed') }
    let!(:completed_collaboration) { create(:tourism_collaboration, status: 'completed') }

    describe '.active' do
      it 'returns only active collaborations' do
        expect(TourismCollaboration.active).to contain_exactly(active_collaboration)
      end
    end

    describe '.by_collaboration_type' do
      let!(:tourism_board_collab) { create(:tourism_collaboration, collaboration_type: 'tourism_board') }
      let!(:marketing_collab) { create(:tourism_collaboration, collaboration_type: 'marketing_partnership') }

      it 'returns collaborations for specific type' do
        expect(TourismCollaboration.by_collaboration_type('tourism_board')).to contain_exactly(tourism_board_collab)
        expect(TourismCollaboration.by_collaboration_type('marketing_partnership')).to contain_exactly(marketing_collab)
      end
    end

    describe '.approved' do
      let!(:approved_collaboration) { create(:tourism_collaboration, status: 'approved') }

      it 'returns only approved collaborations' do
        expect(TourismCollaboration.approved).to contain_exactly(approved_collaboration)
      end
    end
  end

  describe '#details' do
    it 'parses partnership_details as JSON' do
      details_hash = { 'budget_contribution' => 50000, 'resource_sharing' => ['venue', 'marketing'] }
      tourism_collaboration.partnership_details = details_hash.to_json
      
      expect(tourism_collaboration.details).to eq(details_hash)
    end

    it 'returns empty hash if details are invalid' do
      tourism_collaboration.partnership_details = 'invalid json'
      expect(tourism_collaboration.details).to eq({})
    end
  end

  describe '#campaigns' do
    it 'parses marketing_campaigns as JSON' do
      campaigns_hash = { 
        'social_media' => { 'budget' => 10000, 'platforms' => ['facebook', 'instagram'] },
        'print_media' => { 'budget' => 5000, 'outlets' => ['local_newspaper'] }
      }
      tourism_collaboration.marketing_campaigns = campaigns_hash.to_json
      
      expect(tourism_collaboration.campaigns).to eq(campaigns_hash)
    end

    it 'returns empty hash if campaigns are invalid' do
      tourism_collaboration.marketing_campaigns = 'invalid json'
      expect(tourism_collaboration.campaigns).to eq({})
    end
  end

  describe '#analytics' do
    it 'parses visitor_analytics as JSON' do
      analytics_hash = { 
        'total_visitors' => 5000,
        'demographics' => { 'local' => 60, 'regional' => 30, 'international' => 10 },
        'economic_impact' => 250000
      }
      tourism_collaboration.visitor_analytics = analytics_hash.to_json
      
      expect(tourism_collaboration.analytics).to eq(analytics_hash)
    end

    it 'returns empty hash if analytics are invalid' do
      tourism_collaboration.visitor_analytics = 'invalid json'
      expect(tourism_collaboration.analytics).to eq({})
    end
  end

  describe '#approve!' do
    it 'changes status to approved' do
      tourism_collaboration.status = 'proposed'
      tourism_collaboration.save!
      
      expect { tourism_collaboration.approve! }.to change { tourism_collaboration.status }.from('proposed').to('approved')
    end

    it 'sets approved_at timestamp' do
      tourism_collaboration.approved_at = nil
      tourism_collaboration.save!
      
      expect { tourism_collaboration.approve! }.to change { tourism_collaboration.approved_at }.from(nil)
    end
  end

  describe '#activate!' do
    it 'changes status to active' do
      tourism_collaboration.status = 'approved'
      tourism_collaboration.save!
      
      expect { tourism_collaboration.activate! }.to change { tourism_collaboration.status }.from('approved').to('active')
    end

    it 'sets activated_at timestamp' do
      tourism_collaboration.activated_at = nil
      tourism_collaboration.save!
      
      expect { tourism_collaboration.activate! }.to change { tourism_collaboration.activated_at }.from(nil)
    end
  end

  describe '#complete!' do
    it 'changes status to completed' do
      tourism_collaboration.status = 'active'
      tourism_collaboration.save!
      
      expect { tourism_collaboration.complete! }.to change { tourism_collaboration.status }.from('active').to('completed')
    end

    it 'sets completed_at timestamp' do
      tourism_collaboration.completed_at = nil
      tourism_collaboration.save!
      
      expect { tourism_collaboration.complete! }.to change { tourism_collaboration.completed_at }.from(nil)
    end
  end

  describe '#cancel!' do
    it 'changes status to cancelled' do
      tourism_collaboration.status = 'proposed'
      tourism_collaboration.save!
      
      expect { tourism_collaboration.cancel! }.to change { tourism_collaboration.status }.from('proposed').to('cancelled')
    end

    it 'sets cancelled_at timestamp' do
      tourism_collaboration.cancelled_at = nil
      tourism_collaboration.save!
      
      expect { tourism_collaboration.cancel! }.to change { tourism_collaboration.cancelled_at }.from(nil)
    end
  end

  describe '#active?' do
    it 'returns true when status is active' do
      tourism_collaboration.status = 'active'
      expect(tourism_collaboration).to be_active
    end

    it 'returns false when status is not active' do
      tourism_collaboration.status = 'proposed'
      expect(tourism_collaboration).not_to be_active
    end
  end

  describe '#approved?' do
    it 'returns true when status is approved' do
      tourism_collaboration.status = 'approved'
      expect(tourism_collaboration).to be_approved
    end

    it 'returns false when status is not approved' do
      tourism_collaboration.status = 'proposed'
      expect(tourism_collaboration).not_to be_approved
    end
  end

  describe '#completed?' do
    it 'returns true when status is completed' do
      tourism_collaboration.status = 'completed'
      expect(tourism_collaboration).to be_completed
    end

    it 'returns false when status is not completed' do
      tourism_collaboration.status = 'active'
      expect(tourism_collaboration).not_to be_completed
    end
  end

  describe '#economic_impact' do
    it 'returns economic impact from analytics' do
      analytics = { 'economic_impact' => 150000 }
      tourism_collaboration.visitor_analytics = analytics.to_json
      
      expect(tourism_collaboration.economic_impact).to eq(150000)
    end

    it 'returns 0 if no economic impact data' do
      tourism_collaboration.visitor_analytics = '{}'
      expect(tourism_collaboration.economic_impact).to eq(0)
    end
  end

  describe '#total_visitors' do
    it 'returns total visitors from analytics' do
      analytics = { 'total_visitors' => 8500 }
      tourism_collaboration.visitor_analytics = analytics.to_json
      
      expect(tourism_collaboration.total_visitors).to eq(8500)
    end

    it 'returns 0 if no visitor data' do
      tourism_collaboration.visitor_analytics = '{}'
      expect(tourism_collaboration.total_visitors).to eq(0)
    end
  end

  describe '#marketing_budget' do
    it 'calculates total marketing budget from campaigns' do
      campaigns = {
        'social_media' => { 'budget' => 15000 },
        'print_media' => { 'budget' => 8000 },
        'radio' => { 'budget' => 5000 }
      }
      tourism_collaboration.marketing_campaigns = campaigns.to_json
      
      expect(tourism_collaboration.marketing_budget).to eq(28000)
    end

    it 'returns 0 if no campaign budgets' do
      tourism_collaboration.marketing_campaigns = '{}'
      expect(tourism_collaboration.marketing_budget).to eq(0)
    end

    it 'handles campaigns without budget' do
      campaigns = {
        'social_media' => { 'platforms' => ['facebook'] },
        'print_media' => { 'budget' => 5000 }
      }
      tourism_collaboration.marketing_campaigns = campaigns.to_json
      
      expect(tourism_collaboration.marketing_budget).to eq(5000)
    end
  end

  describe '#roi_percentage' do
    it 'calculates ROI based on economic impact and marketing budget' do
      tourism_collaboration.visitor_analytics = { 'economic_impact' => 200000 }.to_json
      campaigns = { 'total' => { 'budget' => 50000 } }
      tourism_collaboration.marketing_campaigns = campaigns.to_json
      
      expect(tourism_collaboration.roi_percentage).to eq(400.0)
    end

    it 'returns 0 if marketing budget is zero' do
      tourism_collaboration.visitor_analytics = { 'economic_impact' => 200000 }.to_json
      tourism_collaboration.marketing_campaigns = '{}'
      
      expect(tourism_collaboration.roi_percentage).to eq(0.0)
    end
  end

  describe '#update_visitor_analytics!' do
    it 'updates visitor analytics with new data' do
      new_analytics = { 'total_visitors' => 6500, 'satisfaction_score' => 4.2 }
      
      expect { tourism_collaboration.update_visitor_analytics!(new_analytics) }
        .to change { tourism_collaboration.visitor_analytics }
      
      expect(tourism_collaboration.analytics).to include(new_analytics.stringify_keys)
    end

    it 'merges with existing analytics' do
      existing_analytics = { 'economic_impact' => 150000 }
      tourism_collaboration.visitor_analytics = existing_analytics.to_json
      tourism_collaboration.save!
      
      new_analytics = { 'total_visitors' => 5000 }
      tourism_collaboration.update_visitor_analytics!(new_analytics)
      
      updated_analytics = tourism_collaboration.analytics
      expect(updated_analytics['economic_impact']).to eq(150000)
      expect(updated_analytics['total_visitors']).to eq(5000)
    end
  end

  describe '#campaign_performance' do
    it 'calculates performance metrics for marketing campaigns' do
      campaigns = {
        'social_media' => { 'budget' => 10000, 'reach' => 50000, 'engagement' => 2500 },
        'print_media' => { 'budget' => 5000, 'reach' => 20000 }
      }
      tourism_collaboration.marketing_campaigns = campaigns.to_json
      
      performance = tourism_collaboration.campaign_performance
      
      expect(performance['social_media']['cost_per_reach']).to eq(0.2)
      expect(performance['social_media']['engagement_rate']).to eq(5.0)
      expect(performance['print_media']['cost_per_reach']).to eq(0.25)
    end

    it 'handles campaigns without performance data' do
      tourism_collaboration.marketing_campaigns = '{}'
      expect(tourism_collaboration.campaign_performance).to eq({})
    end
  end

  describe 'factory' do
    it 'creates valid tourism collaboration' do
      tourism_collaboration = create(:tourism_collaboration)
      expect(tourism_collaboration).to be_valid
      expect(tourism_collaboration).to be_persisted
    end

    it 'creates tourism collaboration with specific type' do
      marketing_collab = create(:tourism_collaboration, collaboration_type: 'marketing_partnership')
      expect(marketing_collab.collaboration_type).to eq('marketing_partnership')
    end
  end

  describe 'database constraints' do
    it 'allows multiple collaborations per festival with different authorities' do
      festival = create(:festival)
      authority1 = create(:municipal_authority)
      authority2 = create(:municipal_authority)
      
      collab1 = create(:tourism_collaboration, festival: festival, municipal_authority: authority1)
      collab2 = create(:tourism_collaboration, festival: festival, municipal_authority: authority2)
      
      expect(collab1).to be_valid
      expect(collab2).to be_valid
    end
  end
end