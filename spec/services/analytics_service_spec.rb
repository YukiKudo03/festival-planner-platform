require 'rails_helper'

RSpec.describe AnalyticsService, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, budget: 100000) }
  let(:service) { described_class.new(festival) }
  
  before do
    # Create test data for comprehensive analysis
    create_test_data
  end
  
  describe '#dashboard_data' do
    it 'returns comprehensive dashboard analytics' do
      result = service.dashboard_data
      
      expect(result).to have_key(:overview)
      expect(result).to have_key(:budget_analytics)
      expect(result).to have_key(:task_analytics)
      expect(result).to have_key(:vendor_analytics)
      expect(result).to have_key(:venue_analytics)
      expect(result).to have_key(:communication_analytics)
      expect(result).to have_key(:trends)
      expect(result).to have_key(:recommendations)
    end
    
    it 'includes overview metrics' do
      result = service.dashboard_data
      overview = result[:overview]
      
      expect(overview).to have_key(:total_budget)
      expect(overview).to have_key(:total_expenses)
      expect(overview).to have_key(:total_revenue)
      expect(overview).to have_key(:budget_utilization)
      expect(overview).to have_key(:vendor_count)
      expect(overview).to have_key(:task_completion_rate)
      expect(overview).to have_key(:days_until_event)
    end
    
    it 'calculates budget utilization correctly' do
      result = service.dashboard_data
      overview = result[:overview]
      
      expect(overview[:budget_utilization]).to be_a(Numeric)
      expect(overview[:budget_utilization]).to be >= 0
      expect(overview[:budget_utilization]).to be <= 100
    end
  end
  
  describe '#budget_analytics' do
    it 'returns detailed budget analysis' do
      result = service.budget_analytics
      
      expect(result).to have_key(:total_budget)
      expect(result).to have_key(:total_expenses)
      expect(result).to have_key(:total_revenue)
      expect(result).to have_key(:net_profit)
      expect(result).to have_key(:category_breakdown)
      expect(result).to have_key(:monthly_trends)
      expect(result).to have_key(:budget_health)
    end
    
    it 'calculates net profit correctly' do
      result = service.budget_analytics
      
      expected_net_profit = result[:total_revenue] - result[:total_expenses]
      expect(result[:net_profit]).to eq(expected_net_profit)
    end
    
    it 'provides category breakdown' do
      result = service.budget_analytics
      breakdown = result[:category_breakdown]
      
      expect(breakdown).to be_an(Array)
      breakdown.each do |category|
        expect(category).to have_key(:name)
        expect(category).to have_key(:budget)
        expect(category).to have_key(:spent)
        expect(category).to have_key(:percentage)
      end
    end
    
    it 'includes budget health assessment' do
      result = service.budget_analytics
      health = result[:budget_health]
      
      expect(health).to have_key(:status)
      expect(health).to have_key(:score)
      expect(health).to have_key(:warnings)
      expect(health[:status]).to be_in(['excellent', 'good', 'warning', 'critical'])
    end
  end
  
  describe '#task_analytics' do
    it 'returns task completion statistics' do
      result = service.task_analytics
      
      expect(result).to have_key(:total_tasks)
      expect(result).to have_key(:completed_tasks)
      expect(result).to have_key(:pending_tasks)
      expect(result).to have_key(:overdue_tasks)
      expect(result).to have_key(:completion_rate)
      expect(result).to have_key(:average_completion_time)
      expect(result).to have_key(:tasks_by_priority)
      expect(result).to have_key(:upcoming_deadlines)
    end
    
    it 'calculates completion rate correctly' do
      result = service.task_analytics
      
      if result[:total_tasks] > 0
        expected_rate = (result[:completed_tasks].to_f / result[:total_tasks] * 100).round(2)
        expect(result[:completion_rate]).to eq(expected_rate)
      else
        expect(result[:completion_rate]).to eq(0.0)
      end
    end
    
    it 'provides task priority breakdown' do
      result = service.task_analytics
      priority_breakdown = result[:tasks_by_priority]
      
      expect(priority_breakdown).to have_key(:high)
      expect(priority_breakdown).to have_key(:medium)
      expect(priority_breakdown).to have_key(:low)
    end
  end
  
  describe '#vendor_analytics' do
    it 'returns vendor application statistics' do
      result = service.vendor_analytics
      
      expect(result).to have_key(:total_applications)
      expect(result).to have_key(:approved_applications)
      expect(result).to have_key(:pending_applications)
      expect(result).to have_key(:rejected_applications)
      expect(result).to have_key(:approval_rate)
      expect(result).to have_key(:revenue_by_category)
      expect(result).to have_key(:top_vendors)
    end
    
    it 'calculates approval rate correctly' do
      result = service.vendor_analytics
      
      if result[:total_applications] > 0
        expected_rate = (result[:approved_applications].to_f / result[:total_applications] * 100).round(2)
        expect(result[:approval_rate]).to eq(expected_rate)
      else
        expect(result[:approval_rate]).to eq(0.0)
      end
    end
    
    it 'provides revenue breakdown by category' do
      result = service.vendor_analytics
      revenue_breakdown = result[:revenue_by_category]
      
      expect(revenue_breakdown).to be_a(Hash)
      revenue_breakdown.each do |category, amount|
        expect(amount).to be_a(Numeric)
        expect(amount).to be >= 0
      end
    end
  end
  
  describe '#venue_analytics' do
    it 'returns venue utilization data' do
      result = service.venue_analytics
      
      expect(result).to have_key(:total_capacity)
      expect(result).to have_key(:allocated_spaces)
      expect(result).to have_key(:utilization_rate)
      expect(result).to have_key(:space_breakdown)
      expect(result).to have_key(:layout_efficiency)
    end
    
    it 'calculates utilization rate correctly' do
      result = service.venue_analytics
      
      if result[:total_capacity] > 0
        expected_rate = (result[:allocated_spaces].to_f / result[:total_capacity] * 100).round(2)
        expect(result[:utilization_rate]).to eq(expected_rate)
      else
        expect(result[:utilization_rate]).to eq(0.0)
      end
    end
  end
  
  describe '#communication_analytics' do
    it 'returns communication activity metrics' do
      result = service.communication_analytics
      
      expect(result).to have_key(:total_messages)
      expect(result).to have_key(:active_discussions)
      expect(result).to have_key(:participant_engagement)
      expect(result).to have_key(:message_trends)
      expect(result).to have_key(:popular_topics)
    end
    
    it 'calculates engagement metrics' do
      result = service.communication_analytics
      engagement = result[:participant_engagement]
      
      expect(engagement).to have_key(:daily_active_users)
      expect(engagement).to have_key(:messages_per_user)
      expect(engagement).to have_key(:engagement_score)
    end
  end
  
  describe '#generate_recommendations' do
    it 'provides actionable recommendations' do
      result = service.generate_recommendations
      
      expect(result).to be_an(Array)
      result.each do |recommendation|
        expect(recommendation).to have_key(:type)
        expect(recommendation).to have_key(:priority)
        expect(recommendation).to have_key(:message)
        expect(recommendation).to have_key(:action)
      end
    end
    
    it 'includes budget recommendations when over budget' do
      # Create scenario where festival is over budget
      budget_category = create(:budget_category, festival: festival, budget_limit: 10000)
      create(:expense, festival: festival, budget_category: budget_category, amount: 15000, status: :approved)
      
      result = service.generate_recommendations
      budget_recommendations = result.select { |r| r[:type] == 'budget' }
      
      expect(budget_recommendations).not_to be_empty
    end
    
    it 'includes task recommendations when completion rate is low' do
      # Create scenario with low task completion
      create_list(:task, 5, festival: festival, status: :pending)
      create(:task, festival: festival, status: :completed)
      
      result = service.generate_recommendations
      task_recommendations = result.select { |r| r[:type] == 'task' }
      
      expect(task_recommendations).not_to be_empty
    end
  end
  
  describe '#export_data' do
    it 'exports data in JSON format' do
      result = service.export_data(:json)
      
      expect(result).to have_key(:format)
      expect(result).to have_key(:data)
      expect(result).to have_key(:generated_at)
      expect(result[:format]).to eq('json')
    end
    
    it 'exports data in CSV format' do
      result = service.export_data(:csv)
      
      expect(result).to have_key(:format)
      expect(result).to have_key(:data)
      expect(result[:format]).to eq('csv')
    end
    
    it 'includes comprehensive data in export' do
      result = service.export_data(:json)
      data = result[:data]
      
      expect(data).to have_key(:overview)
      expect(data).to have_key(:budget_analytics)
      expect(data).to have_key(:task_analytics)
      expect(data).to have_key(:vendor_analytics)
    end
  end
  
  describe '#trend_analysis' do
    it 'analyzes trends over time' do
      result = service.trend_analysis
      
      expect(result).to have_key(:budget_trends)
      expect(result).to have_key(:task_completion_trends)
      expect(result).to have_key(:vendor_application_trends)
      expect(result).to have_key(:communication_trends)
    end
    
    it 'provides predictive insights' do
      result = service.trend_analysis
      
      expect(result).to have_key(:predictions)
      predictions = result[:predictions]
      
      expect(predictions).to have_key(:budget_forecast)
      expect(predictions).to have_key(:completion_forecast)
      expect(predictions).to have_key(:risk_assessment)
    end
  end
  
  describe 'caching behavior' do
    it 'caches dashboard data' do
      expect(Rails.cache).to receive(:fetch).with(
        "analytics_dashboard_#{festival.id}",
        expires_in: 30.minutes
      ).and_call_original
      
      service.dashboard_data
    end
    
    it 'invalidates cache when festival is updated' do
      service.dashboard_data # Populate cache
      
      festival.touch
      
      expect(Rails.cache).to receive(:delete).with("analytics_dashboard_#{festival.id}")
      service.invalidate_cache
    end
  end
  
  describe 'error handling' do
    it 'handles missing data gracefully' do
      empty_festival = create(:festival)
      empty_service = described_class.new(empty_festival)
      
      expect { empty_service.dashboard_data }.not_to raise_error
      
      result = empty_service.dashboard_data
      expect(result[:overview][:vendor_count]).to eq(0)
      expect(result[:overview][:task_completion_rate]).to eq(0.0)
    end
    
    it 'handles nil values in calculations' do
      festival.update(budget: nil)
      
      expect { service.budget_analytics }.not_to raise_error
      
      result = service.budget_analytics
      expect(result[:total_budget]).to eq(0)
    end
  end
  
  describe 'performance' do
    it 'executes dashboard data query efficiently' do
      expect {
        service.dashboard_data
      }.to perform_under(1.second)
    end
    
    it 'uses efficient database queries' do
      expect {
        service.dashboard_data
      }.to make_database_queries(count: be < 20)
    end
  end
  
  private
  
  def create_test_data
    # Create budget categories and expenses
    @venue_category = create(:budget_category, festival: festival, name: '会場費', budget_limit: 30000)
    @marketing_category = create(:budget_category, festival: festival, name: '宣伝費', budget_limit: 20000)
    
    create(:expense, festival: festival, budget_category: @venue_category, amount: 25000, status: :approved)
    create(:expense, festival: festival, budget_category: @marketing_category, amount: 15000, status: :approved)
    
    # Create revenues
    create(:revenue, festival: festival, budget_category: @venue_category, amount: 35000, status: :confirmed)
    
    # Create tasks
    create_list(:task, 3, festival: festival, status: :completed)
    create_list(:task, 2, festival: festival, status: :pending)
    create(:task, festival: festival, status: :in_progress)
    
    # Create vendor applications
    create_list(:vendor_application, 4, festival: festival, status: :approved)
    create_list(:vendor_application, 2, festival: festival, status: :pending)
    create(:vendor_application, festival: festival, status: :rejected)
    
    # Create venue
    @venue = create(:venue, festival: festival, capacity: 1000)
    
    # Create forum and chat data
    @forum = create(:forum, festival: festival)
    @thread = create(:forum_thread, forum: @forum, user: user)
    create_list(:forum_post, 5, forum_thread: @thread, user: user)
    
    @chat_room = create(:chat_room, festival: festival)
    create_list(:chat_message, 10, chat_room: @chat_room, user: user)
  end
end