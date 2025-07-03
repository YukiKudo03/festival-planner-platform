require 'rails_helper'

RSpec.describe Expense, type: :model do
  let(:festival) { create(:festival) }
  let(:budget_category) { create(:budget_category, festival: festival, budget_limit: 100000) }
  let(:user) { create(:user) }
  let(:expense) { create(:expense, festival: festival, budget_category: budget_category, user: user) }

  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:budget_category) }
    it { should belong_to(:user) }
    it { should have_many_attached(:receipts) }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:description) }
    it { should validate_length_of(:description).is_at_most(500) }
    it { should validate_presence_of(:expense_date) }
    it { should validate_presence_of(:payment_method) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:payment_method).in_array(Expense::PAYMENT_METHODS) }
    it { should validate_inclusion_of(:status).in_array(Expense::STATUSES) }
  end

  describe 'scopes' do
    let!(:old_expense) { create(:expense, festival: festival, budget_category: budget_category, user: user, expense_date: 1.month.ago) }
    let!(:new_expense) { create(:expense, festival: festival, budget_category: budget_category, user: user, expense_date: Date.current) }
    
    it 'orders by recent' do
      expect(Expense.recent).to eq([new_expense, old_expense])
    end
    
    it 'filters by status' do
      pending_expense = create(:expense, festival: festival, budget_category: budget_category, user: user, status: 'pending')
      approved_expense = create(:expense, festival: festival, budget_category: budget_category, user: user, status: 'approved')
      
      expect(Expense.by_status('pending')).to include(pending_expense)
      expect(Expense.by_status('pending')).not_to include(approved_expense)
    end
    
    it 'filters by category' do
      other_category = create(:budget_category, festival: festival)
      other_expense = create(:expense, festival: festival, budget_category: other_category, user: user)
      
      expect(Expense.by_category(budget_category)).to include(expense)
      expect(Expense.by_category(budget_category)).not_to include(other_expense)
    end
  end

  describe '#payment_method_text' do
    it 'returns Japanese text for payment methods' do
      expense.update(payment_method: 'cash')
      expect(expense.payment_method_text).to eq('現金')
      
      expense.update(payment_method: 'credit_card')
      expect(expense.payment_method_text).to eq('クレジットカード')
    end
  end

  describe '#status_text' do
    it 'returns Japanese text for statuses' do
      expense.update(status: 'draft')
      expect(expense.status_text).to eq('下書き')
      
      expense.update(status: 'pending')
      expect(expense.status_text).to eq('承認待ち')
      
      expense.update(status: 'approved')
      expect(expense.status_text).to eq('承認済み')
    end
  end

  describe '#status_color' do
    it 'returns correct color for each status' do
      expense.update(status: 'draft')
      expect(expense.status_color).to eq('secondary')
      
      expense.update(status: 'pending')
      expect(expense.status_color).to eq('warning')
      
      expense.update(status: 'approved')
      expect(expense.status_color).to eq('success')
    end
  end

  describe '#can_be_modified_by?' do
    let(:admin) { create(:user, :admin) }
    let(:committee_member) { create(:user, :committee_member) }
    let(:expense_owner) { expense.user }
    let(:other_user) { create(:user) }
    
    it 'allows admin to modify' do
      expect(expense.can_be_modified_by?(admin)).to be true
    end
    
    it 'allows committee member to modify' do
      expect(expense.can_be_modified_by?(committee_member)).to be true
    end
    
    it 'allows expense owner to modify draft/pending expenses' do
      expense.update(status: 'draft')
      expect(expense.can_be_modified_by?(expense_owner)).to be true
      
      expense.update(status: 'pending')
      expect(expense.can_be_modified_by?(expense_owner)).to be true
    end
    
    it 'does not allow expense owner to modify approved expenses' do
      expense.update(status: 'approved')
      expect(expense.can_be_modified_by?(expense_owner)).to be false
    end
    
    it 'does not allow other users to modify' do
      expect(expense.can_be_modified_by?(other_user)).to be false
    end
  end

  describe '#can_be_approved_by?' do
    let(:admin) { create(:user, :admin) }
    let(:committee_member) { create(:user, :committee_member) }
    let(:festival_owner) { festival.user }
    let(:regular_user) { create(:user) }
    
    before { expense.update(status: 'pending') }
    
    it 'allows admin to approve' do
      expect(expense.can_be_approved_by?(admin)).to be true
    end
    
    it 'allows committee member to approve' do
      expect(expense.can_be_approved_by?(committee_member)).to be true
    end
    
    it 'allows festival owner to approve' do
      expect(expense.can_be_approved_by?(festival_owner)).to be true
    end
    
    it 'does not allow regular user to approve' do
      expect(expense.can_be_approved_by?(regular_user)).to be false
    end
    
    it 'does not allow approval of non-pending expenses' do
      expense.update(status: 'approved')
      expect(expense.can_be_approved_by?(admin)).to be false
    end
  end

  describe '#approve!' do
    let(:admin) { create(:user, :admin) }
    
    before { expense.update(status: 'pending') }
    
    it 'approves the expense' do
      expect(expense.approve!(admin)).to be true
      expect(expense.reload.status).to eq('approved')
    end
    
    it 'creates a notification' do
      expect(NotificationService).to receive(:create_notification)
      expense.approve!(admin)
    end
  end

  describe '#reject!' do
    let(:admin) { create(:user, :admin) }
    
    before { expense.update(status: 'pending') }
    
    it 'rejects the expense' do
      expect(expense.reject!(admin, 'Budget exceeded')).to be true
      expect(expense.reload.status).to eq('rejected')
    end
    
    it 'requires a reason' do
      expect(expense.reject!(admin, '')).to be false
    end
    
    it 'creates a notification' do
      expect(NotificationService).to receive(:create_notification)
      expense.reject!(admin, 'Budget exceeded')
    end
  end

  describe '#amount_formatted' do
    it 'formats amount with Japanese yen symbol' do
      expense.update(amount: 10000)
      expect(expense.amount_formatted).to eq('¥10,000')
    end
  end

  describe '#tax_amount' do
    it 'calculates tax amount' do
      expense.update(amount: 10000)
      expect(expense.tax_amount).to eq(1000)
    end
  end

  describe '#amount_including_tax' do
    it 'calculates amount including tax' do
      expense.update(amount: 10000)
      expect(expense.amount_including_tax).to eq(11000)
    end
  end
end
