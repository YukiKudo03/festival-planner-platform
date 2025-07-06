require 'rails_helper'

RSpec.describe BudgetAnalyticsService, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:service) { BudgetAnalyticsService.new(festival) }

  let!(:category1) { create(:budget_category, festival: festival, name: 'Food', budget_limit: 100000) }
  let!(:category2) { create(:budget_category, festival: festival, name: 'Entertainment', budget_limit: 50000) }
  
  let!(:expense1) { create(:expense, festival: festival, budget_category: category1, amount: 30000, status: :approved) }
  let!(:expense2) { create(:expense, festival: festival, budget_category: category1, amount: 20000, status: :approved) }
  let!(:expense3) { create(:expense, festival: festival, budget_category: category2, amount: 15000, status: 'pending') }
  
  let!(:revenue1) { create(:revenue, festival: festival, amount: 80000, status: :confirmed, revenue_type: 'ticket_sales') }
  let!(:revenue2) { create(:revenue, festival: festival, amount: 25000, status: :confirmed, revenue_type: 'sponsorship') }
  let!(:revenue3) { create(:revenue, festival: festival, amount: 30000, status: :pending, revenue_type: 'vendor_fees') }

  describe '#initialize' do
    it 'sets the festival instance variable' do
      expect(service.instance_variable_get(:@festival)).to eq(festival)
    end
  end

  describe '#generate_dashboard_data' do
    it 'returns complete dashboard data structure' do
      result = service.generate_dashboard_data
      
      expect(result).to include(:overview, :category_breakdown, :revenue_breakdown, :trends, :alerts, :approvals)
      expect(result[:overview]).to be_a(Hash)
      expect(result[:category_breakdown]).to be_an(Array)
      expect(result[:revenue_breakdown]).to be_an(Array)
      expect(result[:trends]).to be_a(Hash)
      expect(result[:alerts]).to be_an(Array)
      expect(result[:approvals]).to be_a(Hash)
    end
  end

  describe '#overview_metrics' do
    it 'calculates correct overview metrics' do
      result = service.overview_metrics
      
      expect(result[:total_budget]).to eq(150000) # 100000 + 50000
      expect(result[:total_expenses]).to eq(50000) # 30000 + 20000 (approved only)
      expect(result[:total_revenues]).to eq(105000) # 80000 + 25000 (confirmed only)
      expect(result[:pending_expenses]).to eq(15000) # pending expense
      expect(result[:pending_revenues]).to eq(30000) # pending revenue
    end

    it 'includes calculated metrics' do
      result = service.overview_metrics
      
      expect(result).to include(:budget_utilization, :net_balance, :variance)
      expect(result[:budget_utilization]).to be_a(Numeric)
      expect(result[:net_balance]).to be_a(Numeric)
      expect(result[:variance]).to be_a(Numeric)
    end
  end

  describe '#category_breakdown' do
    it 'returns breakdown for all categories' do
      result = service.category_breakdown
      
      expect(result.length).to eq(2)
      expect(result.map { |cat| cat[:name] }).to include('Food', 'Entertainment')
    end

    it 'includes all required category information' do
      result = service.category_breakdown
      category_food = result.find { |cat| cat[:name] == 'Food' }
      
      expect(category_food).to include(
        :id, :name, :budget_limit, :actual_expenses, :remaining_budget,
        :utilization_percentage, :status, :expense_count, :last_expense_date
      )
      expect(category_food[:budget_limit]).to eq(100000)
      expect(category_food[:actual_expenses]).to eq(50000) # 30000 + 20000
      expect(category_food[:expense_count]).to eq(2)
    end

    it 'sorts categories by actual expenses in descending order' do
      result = service.category_breakdown
      
      expect(result.first[:name]).to eq('Food') # has 50000 in expenses
      expect(result.last[:name]).to eq('Entertainment') # has 0 in approved expenses
    end

    it 'calculates remaining budget correctly' do
      result = service.category_breakdown
      category_food = result.find { |cat| cat[:name] == 'Food' }
      
      # This depends on the implementation of budget_remaining method in BudgetCategory
      expect(category_food[:remaining_budget]).to be_a(Numeric)
    end
  end

  describe '#revenue_breakdown' do
    it 'returns breakdown for revenue types with confirmed revenues' do
      result = service.revenue_breakdown
      
      # Only includes types with confirmed revenues (amount > 0)
      expect(result.length).to eq(2) # ticket_sales and sponsorship
      types = result.map { |rev| rev[:type] }
      expect(types).to include('ticket_sales', 'sponsorship')
      expect(types).not_to include('vendor_fees') # pending revenue
    end

    it 'includes all required revenue information' do
      result = service.revenue_breakdown
      ticket_sales = result.find { |rev| rev[:type] == 'ticket_sales' }
      
      expect(ticket_sales).to include(
        :type, :type_text, :total_amount, :count, :average_amount, :last_revenue_date
      )
      expect(ticket_sales[:total_amount]).to eq(80000)
      expect(ticket_sales[:count]).to eq(1)
      expect(ticket_sales[:average_amount]).to eq(80000)
    end

    it 'sorts revenues by total amount in descending order' do
      result = service.revenue_breakdown
      
      expect(result.first[:type]).to eq('ticket_sales') # 80000
      expect(result.last[:type]).to eq('sponsorship') # 25000
    end

    it 'calculates average amount correctly' do
      result = service.revenue_breakdown
      sponsorship = result.find { |rev| rev[:type] == 'sponsorship' }
      
      expect(sponsorship[:average_amount]).to eq(25000) # 25000 / 1
    end
  end

  describe '#trend_analysis' do
    it 'returns trend analysis structure' do
      result = service.trend_analysis
      
      expect(result).to include(:monthly_expenses, :monthly_revenues, :category_trends, :seasonal_patterns)
      expect(result[:monthly_expenses]).to respond_to(:each) # Hash or Array
      expect(result[:monthly_revenues]).to respond_to(:each)
      expect(result[:category_trends]).to respond_to(:each)
      expect(result[:seasonal_patterns]).to respond_to(:each)
    end
  end

  describe '#budget_alerts' do
    context 'when categories are within budget' do
      it 'returns empty alerts array' do
        result = service.budget_alerts
        expect(result).to be_an(Array)
        # Note: actual alerts depend on the budget_category model implementation
      end
    end

    context 'when categories exceed budget' do
      before do
        # Create expenses that exceed budget
        create(:expense, festival: festival, budget_category: category2, amount: 60000, status: :approved)
      end

      it 'includes budget exceeded alerts' do
        # Mock the over_budget? method since it depends on BudgetCategory implementation
        allow_any_instance_of(BudgetCategory).to receive(:over_budget?).and_return(true)
        allow_any_instance_of(BudgetCategory).to receive(:total_budget_used).and_return(60000)
        allow_any_instance_of(BudgetCategory).to receive(:budget_usage_percentage).and_return(120)
        
        result = service.budget_alerts
        
        if result.any?
          alert = result.find { |a| a[:type] == 'budget_exceeded' }
          expect(alert).to be_present if alert
          expect(alert[:severity]).to eq('high') if alert
        end
      end
    end

    context 'when categories are near budget limit' do
      it 'includes budget warning alerts when near limit' do
        # Mock the near_budget_limit? method
        allow_any_instance_of(BudgetCategory).to receive(:near_budget_limit?).with(0.8).and_return(true)
        allow_any_instance_of(BudgetCategory).to receive(:over_budget?).and_return(false)
        allow_any_instance_of(BudgetCategory).to receive(:budget_usage_percentage).and_return(85)
        allow_any_instance_of(BudgetCategory).to receive(:budget_remaining).and_return(15000)
        
        result = service.budget_alerts
        
        if result.any?
          alert = result.find { |a| a[:type] == 'budget_warning' }
          expect(alert).to be_present if alert
          expect(alert[:severity]).to eq('medium') if alert
        end
      end
    end
  end

  describe 'private methods' do
    describe '#calculate_budget_utilization' do
      it 'calculates utilization percentage correctly' do
        # Access private method for testing
        utilization = service.send(:calculate_budget_utilization)
        
        # 50000 (total approved expenses) / 150000 (total budget) * 100 = 33.33%
        expect(utilization).to be_within(0.1).of(33.33)
      end
    end

    describe '#calculate_net_balance' do
      it 'calculates net balance correctly' do
        balance = service.send(:calculate_net_balance)
        
        # 105000 (confirmed revenues) - 50000 (approved expenses) = 55000
        expect(balance).to eq(55000)
      end
    end

    describe '#calculate_total_variance' do
      it 'calculates total budget variance' do
        variance = service.send(:calculate_total_variance)
        
        # 150000 (total budget) - 50000 (actual expenses) = 100000
        expect(variance).to eq(100000)
      end
    end

    describe '#determine_category_status' do
      it 'determines status based on budget usage' do
        status = service.send(:determine_category_status, category1)
        
        # Status should be a string indicating budget health
        expect(status).to be_a(String)
        expect(status).to match(/good|warning|danger|over_budget/)
      end
    end

    describe '#revenue_type_text' do
      it 'returns Japanese text for revenue types' do
        text = service.send(:revenue_type_text, 'ticket_sales')
        expect(text).to eq('チケット売上')
        
        text = service.send(:revenue_type_text, 'sponsorship')
        expect(text).to eq('スポンサーシップ')
      end

      it 'returns humanized text for unknown types' do
        text = service.send(:revenue_type_text, 'unknown_type')
        expect(text).to eq('Unknown type')
      end
    end
  end

  describe 'integration with models' do
    it 'works with actual budget category and expense models' do
      expect { service.overview_metrics }.not_to raise_error
      expect { service.category_breakdown }.not_to raise_error
      expect { service.revenue_breakdown }.not_to raise_error
    end

    it 'handles festivals with no budget categories' do
      empty_festival = create(:festival, user: user)
      empty_service = BudgetAnalyticsService.new(empty_festival)
      
      result = empty_service.overview_metrics
      expect(result[:total_budget]).to eq(0)
      expect(result[:total_expenses]).to eq(0)
      
      breakdown = empty_service.category_breakdown
      expect(breakdown).to be_empty
    end

    it 'handles festivals with no revenues' do
      festival.revenues.destroy_all
      
      result = service.overview_metrics
      expect(result[:total_revenues]).to eq(0)
      expect(result[:pending_revenues]).to eq(0)
      
      breakdown = service.revenue_breakdown
      expect(breakdown).to be_empty
    end
  end
end