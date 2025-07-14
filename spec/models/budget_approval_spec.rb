require 'rails_helper'

RSpec.describe BudgetApproval, type: :model do
  let(:festival) { create(:festival) }
  let(:budget_category) { create(:budget_category, festival: festival) }
  let(:admin) { create(:user, :admin) }
  let(:budget_approval) { create(:budget_approval, festival: festival, budget_category: budget_category, approver: admin) }

  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:budget_category) }
    it { should belong_to(:approver) }
  end

  describe 'validations' do
    it { should validate_presence_of(:requested_amount) }
    it { should validate_numericality_of(:requested_amount).is_greater_than(0) }
    it { should validate_presence_of(:approved_amount) }
    it { should validate_numericality_of(:approved_amount).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:status) }
    it { should validate_length_of(:notes).is_at_most(1000) }
    it { should validate_inclusion_of(:status).in_array(BudgetApproval::STATUSES) }
  end

  describe 'scopes' do
    let!(:old_approval) { create(:budget_approval, festival: festival, budget_category: budget_category, approver: admin, created_at: 1.day.ago) }
    let!(:new_approval) { create(:budget_approval, festival: festival, budget_category: budget_category, approver: admin, created_at: Time.current) }

    it 'orders by recent' do
      expect(BudgetApproval.recent).to eq([ new_approval, old_approval ])
    end

    it 'filters by status' do
      pending_approval = create(:budget_approval, festival: festival, budget_category: budget_category, approver: admin, status: 'pending')
      approved_approval = create(:budget_approval, festival: festival, budget_category: budget_category, approver: admin, status: 'approved')

      expect(BudgetApproval.by_status('pending')).to include(pending_approval)
      expect(BudgetApproval.by_status('pending')).not_to include(approved_approval)
    end

    it 'filters by approver' do
      other_admin = create(:user, :admin)
      other_approval = create(:budget_approval, festival: festival, budget_category: budget_category, approver: other_admin)

      expect(BudgetApproval.by_approver(admin)).to include(budget_approval)
      expect(BudgetApproval.by_approver(admin)).not_to include(other_approval)
    end
  end

  describe '#status_text' do
    it 'returns Japanese text for statuses' do
      budget_approval.update(status: 'pending')
      expect(budget_approval.status_text).to eq('承認待ち')

      budget_approval.update(status: 'approved')
      expect(budget_approval.status_text).to eq('承認済み')

      budget_approval.update(status: 'rejected')
      expect(budget_approval.status_text).to eq('却下')
    end
  end

  describe '#status_color' do
    it 'returns correct color for each status' do
      budget_approval.update(status: 'pending')
      expect(budget_approval.status_color).to eq('warning')

      budget_approval.update(status: 'approved')
      expect(budget_approval.status_color).to eq('success')

      budget_approval.update(status: 'rejected')
      expect(budget_approval.status_color).to eq('danger')
    end
  end

  describe '#requested_amount_formatted' do
    it 'formats requested amount with Japanese yen symbol' do
      budget_approval.update(requested_amount: 100000)
      expect(budget_approval.requested_amount_formatted).to eq('¥100,000')
    end
  end

  describe '#approved_amount_formatted' do
    it 'formats approved amount with Japanese yen symbol' do
      budget_approval.update(approved_amount: 80000)
      expect(budget_approval.approved_amount_formatted).to eq('¥80,000')
    end
  end

  describe '#difference_amount' do
    it 'calculates difference between approved and requested amounts' do
      budget_approval.update(requested_amount: 100000, approved_amount: 80000)
      expect(budget_approval.difference_amount).to eq(-20000)
    end
  end

  describe '#difference_amount_formatted' do
    it 'formats difference amount with proper prefix' do
      budget_approval.update(requested_amount: 100000, approved_amount: 120000)
      expect(budget_approval.difference_amount_formatted).to eq('+¥20,000')

      budget_approval.update(requested_amount: 100000, approved_amount: 80000)
      expect(budget_approval.difference_amount_formatted).to eq('-¥20,000')
    end
  end

  describe '#approval_percentage' do
    it 'calculates approval percentage' do
      budget_approval.update(requested_amount: 100000, approved_amount: 80000)
      expect(budget_approval.approval_percentage).to eq(80.0)
    end

    it 'returns 0 when requested amount is zero' do
      budget_approval.update(requested_amount: 0, approved_amount: 0)
      expect(budget_approval.approval_percentage).to eq(0)
    end
  end

  describe '#can_be_modified_by?' do
    let(:committee_member) { create(:user, :committee_member) }
    let(:festival_owner) { festival.user }
    let(:regular_user) { create(:user) }

    it 'allows admin to modify' do
      expect(budget_approval.can_be_modified_by?(admin)).to be true
    end

    it 'allows committee member to modify' do
      expect(budget_approval.can_be_modified_by?(committee_member)).to be true
    end

    it 'allows festival owner to modify pending approvals' do
      budget_approval.update(status: 'pending')
      expect(budget_approval.can_be_modified_by?(festival_owner)).to be true
    end

    it 'does not allow regular user to modify' do
      expect(budget_approval.can_be_modified_by?(regular_user)).to be false
    end
  end

  describe '#approve!' do
    let(:approver) { create(:user, :admin) }

    before { budget_approval.update(status: 'pending') }

    it 'approves the budget request' do
      expect(budget_approval.approve!(approver, 90000, 'Approved with reduction')).to be true
      expect(budget_approval.reload.status).to eq('approved')
      expect(budget_approval.approved_amount).to eq(90000)
      expect(budget_approval.notes).to eq('Approved with reduction')
    end

    it 'updates the budget category limit' do
      budget_approval.approve!(approver, 90000, 'Approved')
      expect(budget_category.reload.budget_limit).to eq(90000)
    end
  end

  describe '#reject!' do
    let(:approver) { create(:user, :admin) }

    before { budget_approval.update(status: 'pending') }

    it 'rejects the budget request' do
      expect(budget_approval.reject!(approver, 'Insufficient budget')).to be true
      expect(budget_approval.reload.status).to eq('rejected')
      expect(budget_approval.approved_amount).to eq(0)
      expect(budget_approval.notes).to eq('Insufficient budget')
    end

    it 'requires a reason' do
      expect(budget_approval.reject!(approver, '')).to be false
    end
  end

  describe 'callbacks' do
    it 'creates notification on approval request' do
      expect(NotificationService).to receive(:create_notification)
      create(:budget_approval, festival: festival, budget_category: budget_category, approver: admin)
    end

    it 'creates notification on approval decision' do
      budget_approval.update(status: 'pending')
      expect(NotificationService).to receive(:create_notification)
      budget_approval.update(status: 'approved')
    end
  end
end
