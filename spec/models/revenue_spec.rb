require 'rails_helper'

RSpec.describe Revenue, type: :model do
  let(:festival) { create(:festival) }
  let(:budget_category) { create(:budget_category, festival: festival) }
  let(:user) { create(:user) }
  let(:revenue) { create(:revenue, festival: festival, budget_category: budget_category, user: user) }

  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:budget_category) }
    it { should belong_to(:user) }
    it { should have_many_attached(:documents) }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description).is_at_most(500) }
    it { should validate_presence_of(:revenue_date) }
    it { should validate_presence_of(:revenue_type) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:revenue_type).in_array(Revenue::REVENUE_TYPES) }
    it { should validate_inclusion_of(:status).in_array(Revenue::STATUSES) }
  end

  describe 'scopes' do
    let!(:old_revenue) { create(:revenue, festival: festival, budget_category: budget_category, user: user, revenue_date: 1.month.ago) }
    let!(:new_revenue) { create(:revenue, festival: festival, budget_category: budget_category, user: user, revenue_date: Date.current) }

    it 'orders by recent' do
      expect(Revenue.recent).to eq([ new_revenue, old_revenue ])
    end

    it 'filters by status' do
      pending_revenue = create(:revenue, festival: festival, budget_category: budget_category, user: user, status: 'pending')
      confirmed_revenue = create(:revenue, festival: festival, budget_category: budget_category, user: user, status: 'confirmed')

      expect(Revenue.by_status('pending')).to include(pending_revenue)
      expect(Revenue.by_status('pending')).not_to include(confirmed_revenue)
    end

    it 'filters by type' do
      ticket_revenue = create(:revenue, festival: festival, budget_category: budget_category, user: user, revenue_type: 'ticket_sales')
      sponsor_revenue = create(:revenue, festival: festival, budget_category: budget_category, user: user, revenue_type: 'sponsorship')

      expect(Revenue.by_type('ticket_sales')).to include(ticket_revenue)
      expect(Revenue.by_type('ticket_sales')).not_to include(sponsor_revenue)
    end
  end

  describe '#revenue_type_text' do
    it 'returns Japanese text for revenue types' do
      revenue.update(revenue_type: 'ticket_sales')
      expect(revenue.revenue_type_text).to eq('チケット売上')

      revenue.update(revenue_type: 'sponsorship')
      expect(revenue.revenue_type_text).to eq('スポンサーシップ')
    end
  end

  describe '#status_text' do
    it 'returns Japanese text for statuses' do
      revenue.update(status: 'pending')
      expect(revenue.status_text).to eq('保留中')

      revenue.update(status: 'confirmed')
      expect(revenue.status_text).to eq('確定')

      revenue.update(status: 'received')
      expect(revenue.status_text).to eq('受領済み')
    end
  end

  describe '#status_color' do
    it 'returns correct color for each status' do
      revenue.update(status: 'pending')
      expect(revenue.status_color).to eq('warning')

      revenue.update(status: 'confirmed')
      expect(revenue.status_color).to eq('info')

      revenue.update(status: 'received')
      expect(revenue.status_color).to eq('success')
    end
  end

  describe '#can_be_modified_by?' do
    let(:admin) { create(:user, :admin) }
    let(:committee_member) { create(:user, :committee_member) }
    let(:revenue_owner) { revenue.user }
    let(:other_user) { create(:user) }

    it 'allows admin to modify' do
      expect(revenue.can_be_modified_by?(admin)).to be true
    end

    it 'allows committee member to modify' do
      expect(revenue.can_be_modified_by?(committee_member)).to be true
    end

    it 'allows revenue owner to modify pending revenues' do
      revenue.update(status: 'pending')
      expect(revenue.can_be_modified_by?(revenue_owner)).to be true
    end

    it 'does not allow revenue owner to modify confirmed revenues' do
      revenue.update(status: 'confirmed')
      expect(revenue.can_be_modified_by?(revenue_owner)).to be false
    end

    it 'does not allow other users to modify' do
      expect(revenue.can_be_modified_by?(other_user)).to be false
    end
  end

  describe '#can_be_confirmed_by?' do
    let(:admin) { create(:user, :admin) }
    let(:committee_member) { create(:user, :committee_member) }
    let(:festival_owner) { festival.user }
    let(:regular_user) { create(:user) }

    before { revenue.update(status: 'pending') }

    it 'allows admin to confirm' do
      expect(revenue.can_be_confirmed_by?(admin)).to be true
    end

    it 'allows committee member to confirm' do
      expect(revenue.can_be_confirmed_by?(committee_member)).to be true
    end

    it 'allows festival owner to confirm' do
      expect(revenue.can_be_confirmed_by?(festival_owner)).to be true
    end

    it 'does not allow regular user to confirm' do
      expect(revenue.can_be_confirmed_by?(regular_user)).to be false
    end

    it 'does not allow confirmation of non-pending revenues' do
      revenue.update(status: 'confirmed')
      expect(revenue.can_be_confirmed_by?(admin)).to be false
    end
  end

  describe '#confirm!' do
    let(:admin) { create(:user, :admin) }

    before { revenue.update(status: 'pending') }

    it 'confirms the revenue' do
      expect(revenue.confirm!(admin)).to be true
      expect(revenue.reload.status).to eq('confirmed')
    end

    it 'creates a notification' do
      expect(NotificationService).to receive(:create_notification).twice
      revenue.confirm!(admin)
    end
  end

  describe '#mark_received!' do
    let(:admin) { create(:user, :admin) }

    before { revenue.update(status: 'confirmed') }

    it 'marks revenue as received' do
      expect(revenue.mark_received!(admin)).to be true
      expect(revenue.reload.status).to eq('received')
    end

    it 'creates a notification' do
      expect(NotificationService).to receive(:create_notification).twice
      revenue.mark_received!(admin)
    end
  end

  describe '#amount_formatted' do
    it 'formats amount with Japanese yen symbol' do
      revenue.update(amount: 50000)
      expect(revenue.amount_formatted).to eq('¥50,000')
    end
  end

  describe '#tax_amount' do
    it 'calculates tax amount' do
      revenue.update(amount: 10000)
      expect(revenue.tax_amount).to eq(1000)
    end
  end

  describe '#amount_including_tax' do
    it 'calculates amount including tax' do
      revenue.update(amount: 10000)
      expect(revenue.amount_including_tax).to eq(11000)
    end
  end
end
