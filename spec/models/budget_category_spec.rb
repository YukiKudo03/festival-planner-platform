require 'rails_helper'

RSpec.describe BudgetCategory, type: :model do
  let(:festival) { create(:festival) }
  let(:budget_category) { create(:budget_category, festival: festival, budget_limit: 100000) }

  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:parent).optional }
    it { should have_many(:expenses).dependent(:destroy) }
    it { should have_many(:revenues).dependent(:destroy) }
    it { should have_many(:budget_approvals).dependent(:destroy) }
    it { should have_many(:child_categories).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500) }
    it { should validate_presence_of(:budget_limit) }
    it { should validate_numericality_of(:budget_limit).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:root_category) { create(:budget_category, festival: festival, parent: nil) }
    let!(:child_category) { create(:budget_category, festival: festival, parent: root_category) }

    it 'returns root categories' do
      expect(described_class.root_categories).to include(root_category)
      expect(described_class.root_categories).not_to include(child_category)
    end

    it 'returns categories by festival' do
      other_festival = create(:festival)
      other_category = create(:budget_category, festival: other_festival)

      expect(described_class.by_festival(festival)).to include(root_category, child_category)
      expect(described_class.by_festival(festival)).not_to include(other_category)
    end
  end

  describe '#total_expenses' do
    it 'calculates total expenses including child categories' do
      child_category = create(:budget_category, festival: festival, parent: budget_category)
      create(:expense, budget_category: budget_category, amount: 10000, status: 'approved')
      create(:expense, budget_category: child_category, amount: 5000, status: 'approved')

      expect(budget_category.total_expenses).to eq(15000)
    end
  end

  describe '#total_revenues' do
    it 'calculates total revenues including child categories' do
      child_category = create(:budget_category, festival: festival, parent: budget_category)
      create(:revenue, budget_category: budget_category, amount: 20000, status: 'confirmed')
      create(:revenue, budget_category: child_category, amount: 10000, status: 'confirmed')

      expect(budget_category.total_revenues).to eq(30000)
    end
  end

  describe '#budget_usage_percentage' do
    it 'calculates usage percentage correctly' do
      create(:expense, budget_category: budget_category, amount: 25000, status: 'approved')

      expect(budget_category.budget_usage_percentage).to eq(25.0)
    end

    it 'returns 0 when budget limit is zero' do
      budget_category.update(budget_limit: 0)
      expect(budget_category.budget_usage_percentage).to eq(0)
    end
  end

  describe '#over_budget?' do
    it 'returns true when over budget' do
      create(:expense, budget_category: budget_category, amount: 150000, status: 'approved')

      expect(budget_category.over_budget?).to be true
    end

    it 'returns false when within budget' do
      create(:expense, budget_category: budget_category, amount: 50000, status: 'approved')

      expect(budget_category.over_budget?).to be false
    end
  end

  describe '#near_budget_limit?' do
    it 'returns true when near budget limit' do
      create(:expense, budget_category: budget_category, amount: 85000, status: 'approved')

      expect(budget_category.near_budget_limit?).to be true
    end

    it 'returns false when not near budget limit' do
      create(:expense, budget_category: budget_category, amount: 50000, status: 'approved')

      expect(budget_category.near_budget_limit?).to be false
    end
  end

  describe '#hierarchy_path' do
    it 'returns correct hierarchy path' do
      parent = create(:budget_category, festival: festival, name: 'Parent')
      child = create(:budget_category, festival: festival, name: 'Child', parent: parent)

      expect(child.hierarchy_path).to eq('Parent > Child')
    end
  end

  describe '#can_be_modified_by?' do
    let(:admin) { create(:user, :admin) }
    let(:committee_member) { create(:user, :committee_member) }
    let(:festival_owner) { festival.user }
    let(:regular_user) { create(:user) }

    it 'allows admin to modify' do
      expect(budget_category.can_be_modified_by?(admin)).to be true
    end

    it 'allows committee member to modify' do
      expect(budget_category.can_be_modified_by?(committee_member)).to be true
    end

    it 'allows festival owner to modify' do
      expect(budget_category.can_be_modified_by?(festival_owner)).to be true
    end

    it 'does not allow regular user to modify' do
      expect(budget_category.can_be_modified_by?(regular_user)).to be false
    end
  end

  describe '.create_standard_categories_for' do
    it 'creates standard categories for a festival' do
      expect {
        described_class.create_standard_categories_for(festival)
      }.to change(festival.budget_categories, :count).by(9)  # 9 new categories (1 overlaps with default)
    end

    it 'does not create duplicate categories' do
      described_class.create_standard_categories_for(festival)
      expect {
        described_class.create_standard_categories_for(festival)
      }.not_to change(festival.budget_categories, :count)
    end
  end
end
