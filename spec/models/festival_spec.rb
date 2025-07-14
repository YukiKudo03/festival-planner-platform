require 'rails_helper'

RSpec.describe Festival, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_presence_of(:location) }

    it 'validates end_date is after start_date' do
      festival = build(:festival, start_date: Date.tomorrow, end_date: Date.current)
      expect(festival).not_to be_valid
      expect(festival.errors[:end_date]).to include('must be after start date')
    end

    it 'validates budget is positive' do
      festival = build(:festival, budget: -1000)
      expect(festival).not_to be_valid
      expect(festival.errors[:budget]).to include('must be greater than 0')
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:budget_categories).dependent(:destroy) }
    it { should have_many(:expenses).dependent(:destroy) }
    it { should have_many(:revenues).dependent(:destroy) }
    it { should have_many(:vendor_applications).dependent(:destroy) }
    it { should have_many(:tasks).dependent(:destroy) }
    it { should have_many(:payments).dependent(:destroy) }
    it { should have_many(:venues).dependent(:destroy) }
    it { should have_many(:forums).dependent(:destroy) }
    it { should have_many(:chat_rooms).dependent(:destroy) }
    it { should have_many(:notifications).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values([ :planning, :scheduled, :active, :completed, :cancelled ]) }
  end

  describe 'scopes' do
    let!(:active_festival) { create(:festival, status: :active) }
    let!(:planning_festival) { create(:festival, status: :planning) }
    let!(:public_festival) { create(:festival, public: true) }
    let!(:private_festival) { create(:festival, public: false) }

    describe '.active' do
      it 'returns only active festivals' do
        expect(Festival.active).to include(active_festival)
        expect(Festival.active).not_to include(planning_festival)
      end
    end

    describe '.public_festivals' do
      it 'returns only public festivals' do
        expect(Festival.public_festivals).to include(public_festival)
        expect(Festival.public_festivals).not_to include(private_festival)
      end
    end

    describe '.upcoming' do
      let!(:upcoming_festival) { create(:festival, start_date: 1.week.from_now) }
      let!(:past_festival) { create(:festival, start_date: 1.week.ago) }

      it 'returns festivals starting in the future' do
        expect(Festival.upcoming).to include(upcoming_festival)
        expect(Festival.upcoming).not_to include(past_festival)
      end
    end
  end

  describe 'instance methods' do
    let(:festival) { create(:festival, start_date: Date.current, end_date: Date.current + 2.days) }

    describe '#duration_days' do
      it 'calculates the duration in days' do
        expect(festival.duration_days).to eq(3)
      end
    end

    describe '#budget_utilization_rate' do
      let!(:budget_category) { create(:budget_category, festival: festival, budget_limit: 10000) }
      let!(:expense) { create(:expense, festival: festival, budget_category: budget_category, amount: 3000, status: :approved) }

      before do
        # Clear default budget categories created by callback
        festival.budget_categories.where.not(id: budget_category.id).destroy_all
      end

      it 'calculates budget utilization rate' do
        expect(festival.budget_utilization_rate).to eq(30.0)
      end

      it 'returns 0 when no budget is set' do
        festival.budget_categories.destroy_all
        expect(festival.budget_utilization_rate).to eq(0.0)
      end
    end

    describe '#total_expenses' do
      let!(:budget_category) { create(:budget_category, festival: festival) }
      let!(:approved_expense) { create(:expense, festival: festival, budget_category: budget_category, amount: 1000, status: :approved) }
      let!(:pending_expense) { create(:expense, festival: festival, budget_category: budget_category, amount: 500, status: :pending) }

      it 'calculates total approved expenses' do
        expect(festival.total_expenses).to eq(1000)
      end
    end

    describe '#total_revenues' do
      let!(:budget_category) { create(:budget_category, festival: festival) }
      let!(:confirmed_revenue) { create(:revenue, festival: festival, budget_category: budget_category, amount: 2000, status: :confirmed) }
      let!(:pending_revenue) { create(:revenue, festival: festival, budget_category: budget_category, amount: 1000, status: :pending) }

      it 'calculates total confirmed revenues' do
        expect(festival.total_revenues).to eq(2000)
      end
    end

    describe '#completion_rate' do
      let!(:completed_task) { create(:task, festival: festival, status: :completed) }
      let!(:pending_task) { create(:task, festival: festival, status: :pending) }

      it 'calculates task completion rate' do
        expect(festival.completion_rate).to eq(50.0)
      end

      it 'returns 0 when no tasks exist' do
        festival.tasks.destroy_all
        expect(festival.completion_rate).to eq(0.0)
      end
    end

    describe '#vendor_approval_rate' do
      let!(:approved_application) { create(:vendor_application, festival: festival, status: :approved) }
      let!(:under_review_application) { create(:vendor_application, festival: festival, status: :under_review) }

      it 'calculates vendor approval rate' do
        expect(festival.vendor_approval_rate).to eq(50.0)
      end
    end

    describe '#total_payments_amount' do
      let!(:completed_payment) { create(:payment, festival: festival, status: :completed, amount: 5000) }
      let!(:pending_payment) { create(:payment, festival: festival, status: :pending, amount: 3000) }

      it 'calculates total completed payments' do
        expect(festival.total_payments_amount).to eq(5000)
      end
    end

    describe '#can_be_edited_by?' do
      let(:owner) { festival.user }
      let(:admin) { create(:user, role: :admin) }
      let(:other_user) { create(:user) }

      it 'allows owner to edit' do
        expect(festival.can_be_edited_by?(owner)).to be true
      end

      it 'allows admin to edit' do
        expect(festival.can_be_edited_by?(admin)).to be true
      end

      it 'does not allow other users to edit' do
        expect(festival.can_be_edited_by?(other_user)).to be false
      end
    end

    describe '#status_color' do
      it 'returns correct color for each status' do
        expect(build(:festival, status: :planning).status_color).to eq('secondary')
        expect(build(:festival, status: :active).status_color).to eq('success')
        expect(build(:festival, status: :completed).status_color).to eq('primary')
        expect(build(:festival, status: :cancelled).status_color).to eq('danger')
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'creates default budget categories' do
        festival = build(:festival)
        expect { festival.save }.to change { BudgetCategory.count }.by_at_least(1)
      end

      it 'creates a default venue' do
        festival = build(:festival)
        expect { festival.save }.to change { Venue.count }.by(1)
      end
    end
  end

  describe 'search and filtering' do
    let!(:summer_festival) { create(:festival, name: 'Summer Festival', location: 'Tokyo') }
    let!(:winter_festival) { create(:festival, name: 'Winter Celebration', location: 'Osaka') }

    describe '.search' do
      it 'finds festivals by name' do
        results = Festival.search('Summer')
        expect(results).to include(summer_festival)
        expect(results).not_to include(winter_festival)
      end

      it 'finds festivals by location' do
        results = Festival.search('Tokyo')
        expect(results).to include(summer_festival)
        expect(results).not_to include(winter_festival)
      end
    end
  end
end
