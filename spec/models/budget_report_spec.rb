require 'rails_helper'

RSpec.describe BudgetReport, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, start_date: 1.month.from_now, end_date: 2.months.from_now) }
  let(:budget_report) { BudgetReport.new(festival: festival) }

  describe 'validations' do
    it 'validates presence of festival' do
      report = BudgetReport.new(festival: nil)
      expect(report).not_to be_valid
      expect(report.errors[:festival]).to include("can't be blank")
    end

    it 'validates presence of start_date' do
      report = BudgetReport.new(festival: festival, start_date: nil)
      expect(report).not_to be_valid
      expect(report.errors[:start_date]).to include("can't be blank")
    end

    it 'validates presence of end_date' do
      report = BudgetReport.new(festival: festival, end_date: nil)
      expect(report).not_to be_valid
      expect(report.errors[:end_date]).to include("can't be blank")
    end

    it 'validates end_date is after start_date' do
      report = BudgetReport.new(
        festival: festival,
        start_date: Date.current,
        end_date: Date.current - 1.day
      )
      expect(report).not_to be_valid
      expect(report.errors[:end_date]).to include('終了日は開始日より後である必要があります')
    end
  end

  describe 'initialization' do
    context 'with festival dates' do
      it 'sets default dates from festival' do
        report = BudgetReport.new(festival: festival)
        expect(report.start_date).to eq(festival.start_date.to_date)
        expect(report.end_date).to eq(festival.end_date.to_date)
      end
    end

    context 'without festival dates' do
      # Since Festival model requires dates, test with nil festival instead
      it 'sets default dates to current month without festival' do
        report = BudgetReport.new(festival: nil)
        expect(report.start_date).to eq(Date.current.beginning_of_month)
        expect(report.end_date).to eq(Date.current.end_of_month)
      end
    end
  end

  describe 'budget calculations' do
    let!(:category1) { create(:budget_category, festival: festival, budget_limit: 10000) }
    let!(:category2) { create(:budget_category, festival: festival, budget_limit: 15000) }

    describe '#total_budget_limit' do
      it 'calculates total budget limit from all categories' do
        expect(budget_report.total_budget_limit).to eq(25000)
      end
    end

    describe '#total_expenses' do
      let!(:expense1) { create(:expense, festival: festival, amount: 5000, status: :approved, expense_date: festival.start_date + 1.week) }
      let!(:expense2) { create(:expense, festival: festival, amount: 3000, status: :approved, expense_date: festival.start_date + 2.weeks) }
      let!(:pending_expense) { create(:expense, festival: festival, amount: 2000, status: :pending, expense_date: festival.start_date + 3.weeks) }

      it 'calculates total approved expenses in period' do
        expect(budget_report.total_expenses).to eq(8000)
      end

      it 'excludes pending expenses' do
        expect(budget_report.total_expenses).not_to include(pending_expense.amount)
      end
    end

    describe '#total_revenues' do
      let!(:revenue1) { create(:revenue, festival: festival, amount: 20000, status: :confirmed, revenue_date: festival.start_date + 1.week) }
      let!(:revenue2) { create(:revenue, festival: festival, amount: 10000, status: :received, revenue_date: festival.start_date + 2.weeks) }
      let!(:pending_revenue) { create(:revenue, festival: festival, amount: 5000, status: :pending, revenue_date: festival.start_date + 3.weeks) }

      it 'calculates total confirmed and received revenues in period' do
        expect(budget_report.total_revenues).to eq(30000)
      end

      it 'excludes pending revenues' do
        expect(budget_report.total_revenues).not_to include(pending_revenue.amount)
      end
    end

    describe '#net_balance' do
      let!(:expense) { create(:expense, festival: festival, amount: 5000, status: :approved, expense_date: festival.start_date + 1.week) }
      let!(:revenue) { create(:revenue, festival: festival, amount: 8000, status: :confirmed, revenue_date: festival.start_date + 1.week) }

      it 'calculates net balance as revenues minus expenses' do
        expect(budget_report.net_balance).to eq(3000)
      end
    end

    describe '#budget_utilization_percentage' do
      let!(:expense) { create(:expense, festival: festival, amount: 5000, status: :approved, expense_date: festival.start_date + 1.week) }

      it 'calculates budget utilization percentage' do
        expect(budget_report.budget_utilization_percentage).to eq(20.0) # 5000/25000 * 100
      end

      context 'when total budget limit is zero' do
        before do
          allow(budget_report).to receive(:total_budget_limit).and_return(0)
        end

        it 'returns 0' do
          expect(budget_report.budget_utilization_percentage).to eq(0)
        end
      end
    end
  end

  describe 'analysis methods' do
    let!(:category) { create(:budget_category, festival: festival, budget_limit: 10000) }
    let!(:expense) { create(:expense, festival: festival, budget_category: category, amount: 3000, status: :approved, expense_date: festival.start_date + 1.week) }

    describe '#expenses_by_category' do
      it 'returns expenses grouped by category' do
        result = budget_report.expenses_by_category
        expect(result).to be_an(Array)
        expect(result.first[:category]).to eq(category)
        expect(result.first[:amount]).to eq(3000)
        expect(result.first[:percentage]).to eq(30.0)
      end
    end

    describe '#budget_variance_analysis' do
      it 'returns variance analysis for each category' do
        result = budget_report.budget_variance_analysis
        expect(result).to be_an(Array)
        
        variance_item = result.first
        expect(variance_item[:category]).to eq(category)
        expect(variance_item[:budgeted]).to eq(10000)
        expect(variance_item[:actual]).to eq(3000)
        expect(variance_item[:variance]).to eq(7000)
        expect(variance_item[:status]).to eq('under_budget')
      end
    end
  end

  describe 'export methods' do
    describe '#export_to_csv' do
      it 'exports data to CSV format' do
        csv_data = budget_report.export_to_csv
        expect(csv_data).to be_a(String)
        expect(csv_data).to include('カテゴリ')
        expect(csv_data).to include('予算額')
      end
    end

    describe '#export_to_json' do
      it 'exports data to JSON format' do
        json_data = budget_report.export_to_json
        parsed_data = JSON.parse(json_data)
        
        expect(parsed_data['festival']).to eq(festival.name)
        expect(parsed_data['summary']).to include('total_budget', 'total_expenses', 'total_revenues')
        expect(parsed_data).to include('categories', 'revenues', 'variance_analysis', 'alerts')
      end
    end
  end

  describe 'date filtering' do
    let(:report_with_custom_dates) { 
      BudgetReport.new(
        festival: festival,
        start_date: Date.current,
        end_date: Date.current + 1.month
      )
    }

    it 'uses custom date range for calculations' do
      expect(report_with_custom_dates.start_date).to eq(Date.current)
      expect(report_with_custom_dates.end_date).to eq(Date.current + 1.month)
    end
  end

  describe 'ActiveModel integration' do
    it 'includes ActiveModel::Model' do
      expect(BudgetReport.included_modules).to include(ActiveModel::Model)
    end

    it 'includes ActiveModel::Attributes' do
      expect(BudgetReport.included_modules).to include(ActiveModel::Attributes)
    end

    it 'responds to attribute methods' do
      expect(budget_report).to respond_to(:festival)
      expect(budget_report).to respond_to(:start_date)
      expect(budget_report).to respond_to(:end_date)
    end
  end
end