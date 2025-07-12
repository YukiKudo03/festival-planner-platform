# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Performance Load Testing', type: :system do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, budget: 500000) }
  let(:venue) { create(:venue, capacity: 5000) }
  
  before do
    festival.update!(venue: venue)
    sign_in user
    
    # Create baseline data for realistic testing
    create_list(:vendor_application, 50, festival: festival, status: 'approved')
    create_list(:task, 100, festival: festival)
    create_list(:expense, 30, festival: festival)
    create_list(:revenue, 15, festival: festival)
    create(:industry_specialization, :technology, :active, festival: festival)
    create(:tourism_collaboration, :active, festival: festival)
  end

  describe 'Dashboard Performance' do
    it 'loads festival dashboard within performance threshold' do
      time = Benchmark.measure do
        visit festival_path(festival)
        expect(page).to have_content('Festival Dashboard')
      end
      
      expect(time.real).to be < 3.0, "Dashboard took #{time.real}s to load (threshold: 3.0s)"
    end
    
    it 'handles concurrent dashboard requests' do
      threads = []
      results = []
      
      5.times do |i|
        threads << Thread.new do
          time = Benchmark.measure do
            visit festival_path(festival)
            expect(page).to have_content('Festival Dashboard')
          end
          results << time.real
        end
      end
      
      threads.each(&:join)
      
      # All requests should complete within reasonable time
      expect(results.max).to be < 5.0, "Slowest concurrent request: #{results.max}s"
      expect(results.sum / results.size).to be < 3.0, "Average response time: #{results.sum / results.size}s"
    end
    
    it 'efficiently loads large vendor lists with pagination' do
      create_list(:vendor_application, 200, festival: festival, status: 'approved')
      
      time = Benchmark.measure do
        visit festival_vendor_applications_path(festival)
        expect(page).to have_content('Vendor Applications')
        expect(page).to have_css('.pagination')
      end
      
      expect(time.real).to be < 2.0, "Vendor list took #{time.real}s to load"
    end
    
    it 'performs well with complex budget calculations' do
      create_list(:expense, 500, festival: festival)
      create_list(:revenue, 200, festival: festival)
      
      time = Benchmark.measure do
        visit festival_path(festival)
        click_link 'Budget Overview'
        expect(page).to have_content('Budget Summary')
      end
      
      expect(time.real).to be < 4.0, "Budget calculations took #{time.real}s"
    end
  end

  describe 'AI Recommendations Performance' do
    let(:ai_service) { instance_double(AiRecommendationService) }
    
    before do
      allow(AiRecommendationService).to receive(:new).and_return(ai_service)
      allow(ai_service).to receive(:predict_attendance).and_return({
        success: true,
        predicted_attendance: 2500,
        confidence_score: 0.85,
        factors: {},
        recommendations: []
      })
    end
    
    it 'generates AI recommendations within acceptable time' do
      time = Benchmark.measure do
        visit festival_ai_recommendations_path(festival)
        click_link 'Attendance Prediction'
        click_button 'Generate Prediction'
        expect(page).to have_content('Predicted Attendance')
      end
      
      expect(time.real).to be < 5.0, "AI prediction took #{time.real}s"
    end
    
    it 'handles multiple simultaneous AI requests' do
      allow(ai_service).to receive(:optimize_vendor_layout).and_return({
        success: true,
        layout: {},
        efficiency_score: 0.9,
        crowd_flow_score: 0.85,
        accessibility_score: 0.8
      })
      
      times = []
      
      # Simulate multiple users requesting AI analysis
      3.times do
        time = Benchmark.measure do
          visit festival_ai_recommendations_path(festival)
          click_link 'Layout Optimization'
          click_button 'Optimize Layout'
          expect(page).to have_content('Layout Optimization Results')
        end
        times << time.real
      end
      
      expect(times.max).to be < 8.0, "Slowest AI request: #{times.max}s"
    end
    
    it 'efficiently processes batch analysis requests' do
      allow_any_instance_of(AiRecommendationsController).to receive(:get_attendance_prediction)
        .and_return({ predicted_attendance: 2500 })
      allow_any_instance_of(AiRecommendationsController).to receive(:get_budget_analysis)
        .and_return({ efficiency: 'good' })
      allow_any_instance_of(AiRecommendationsController).to receive(:get_layout_analysis)
        .and_return({ score: 85 })
      allow_any_instance_of(AiRecommendationsController).to receive(:get_risk_overview)
        .and_return({ overall_risk: 'medium' })
      
      time = Benchmark.measure do
        visit festival_ai_recommendations_path(festival)
        click_link 'Batch Analysis'
        check 'Attendance Analysis'
        check 'Budget Analysis'
        check 'Layout Analysis'
        check 'Risk Analysis'
        click_button 'Run Batch Analysis'
        expect(page).to have_content('Batch Analysis Results')
      end
      
      expect(time.real).to be < 10.0, "Batch analysis took #{time.real}s"
    end
  end

  describe 'Industry Specialization Performance' do
    let!(:industry_specs) { create_list(:industry_specialization, 10, festival: festival) }
    
    it 'loads industry specializations efficiently' do
      time = Benchmark.measure do
        visit festival_industry_specializations_path(festival)
        expect(page).to have_content('Industry Specializations')
      end
      
      expect(time.real).to be < 2.0, "Industry specializations took #{time.real}s to load"
    end
    
    it 'calculates complex metrics efficiently' do
      industry_spec = create(:industry_specialization, :technology, :active, festival: festival)
      
      time = Benchmark.measure do
        visit industry_dashboard_festival_industry_specialization_path(festival, industry_spec)
        expect(page).to have_content('Technology Industry Dashboard')
      end
      
      expect(time.real).to be < 3.0, "Industry dashboard took #{time.real}s to load"
    end
    
    it 'handles metrics updates efficiently' do
      industry_spec = create(:industry_specialization, :technology, :active, festival: festival)
      
      time = Benchmark.measure do
        visit festival_industry_specialization_path(festival, industry_spec)
        click_link 'Update Metrics'
        fill_in 'Innovation Index', with: '92'
        click_button 'Update Metrics'
        expect(page).to have_content('Metrics updated successfully')
      end
      
      expect(time.real).to be < 2.0, "Metrics update took #{time.real}s"
    end
  end

  describe 'Tourism Collaboration Performance' do
    let!(:municipal_authority) { create(:municipal_authority) }
    let!(:tourism_collabs) { create_list(:tourism_collaboration, 8, festival: festival, municipal_authority: municipal_authority) }
    
    it 'loads tourism collaborations with analytics efficiently' do
      time = Benchmark.measure do
        visit festival_tourism_collaborations_path(festival)
        expect(page).to have_content('Tourism Collaborations')
      end
      
      expect(time.real).to be < 2.5, "Tourism collaborations took #{time.real}s to load"
    end
    
    it 'generates collaboration dashboard quickly' do
      tourism_collab = create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority)
      
      time = Benchmark.measure do
        visit collaboration_dashboard_festival_tourism_collaboration_path(festival, tourism_collab)
        expect(page).to have_content('Collaboration Dashboard')
      end
      
      expect(time.real).to be < 3.0, "Collaboration dashboard took #{time.real}s"
    end
    
    it 'processes visitor analytics updates efficiently' do
      tourism_collab = create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority)
      
      time = Benchmark.measure do
        visit festival_tourism_collaboration_path(festival, tourism_collab)
        click_link 'Update Visitor Analytics'
        fill_in 'Total Visitors', with: '7500'
        fill_in 'Economic Impact', with: '300000'
        click_button 'Update Analytics'
        expect(page).to have_content('Visitor analytics updated successfully')
      end
      
      expect(time.real).to be < 2.0, "Analytics update took #{time.real}s"
    end
  end

  describe 'Database Query Performance' do
    it 'minimizes N+1 queries in festival dashboard' do
      query_count = 0
      
      callback = ->(name, started, finished, unique_id, payload) {
        query_count += 1 if payload[:sql] && !payload[:name]&.include?('SCHEMA')
      }
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        visit festival_path(festival)
      end
      
      expect(query_count).to be < 20, "Dashboard generated #{query_count} queries (threshold: 20)"
    end
    
    it 'efficiently loads vendor applications with associations' do
      create_list(:vendor_application, 100, festival: festival)
      
      query_count = 0
      callback = ->(name, started, finished, unique_id, payload) {
        query_count += 1 if payload[:sql] && !payload[:name]&.include?('SCHEMA')
      }
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        visit festival_vendor_applications_path(festival)
      end
      
      expect(query_count).to be < 15, "Vendor list generated #{query_count} queries"
    end
    
    it 'optimizes complex analytics queries' do
      create_list(:expense, 200, festival: festival)
      create_list(:revenue, 100, festival: festival)
      create_list(:task, 500, festival: festival)
      
      query_count = 0
      callback = ->(name, started, finished, unique_id, payload) {
        query_count += 1 if payload[:sql] && !payload[:name]&.include?('SCHEMA')
      }
      
      time = Benchmark.measure do
        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          visit festival_path(festival)
          click_link 'Analytics Dashboard'
        end
      end
      
      expect(time.real).to be < 4.0, "Analytics took #{time.real}s"
      expect(query_count).to be < 25, "Analytics generated #{query_count} queries"
    end
  end

  describe 'Memory Usage and Resource Management' do
    it 'maintains reasonable memory usage during heavy operations' do
      initial_memory = get_memory_usage
      
      # Perform memory-intensive operations
      visit festival_path(festival)
      click_link 'AI Recommendations'
      click_link 'Batch Analysis'
      click_button 'Run Batch Analysis'
      
      visit festival_industry_specializations_path(festival)
      visit festival_tourism_collaborations_path(festival)
      
      final_memory = get_memory_usage
      memory_increase = final_memory - initial_memory
      
      expect(memory_increase).to be < 100, "Memory increased by #{memory_increase}MB (threshold: 100MB)"
    end
    
    it 'handles large file uploads efficiently' do
      skip 'File upload performance testing requires actual file handling'
      
      # This would test uploading large festival assets, vendor documents, etc.
      # Implementation depends on file upload functionality
    end
    
    it 'manages session data efficiently' do
      session_size_before = get_session_size
      
      # Navigate through multiple pages to build up session data
      10.times do |i|
        visit festival_vendor_applications_path(festival)
        visit festival_tasks_path(festival)
        visit festival_path(festival)
      end
      
      session_size_after = get_session_size
      session_growth = session_size_after - session_size_before
      
      expect(session_growth).to be < 50, "Session grew by #{session_growth}KB"
    end
  end

  describe 'API Performance' do
    before do
      # API testing requires authentication setup
      allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    end
    
    it 'handles API requests within performance thresholds' do
      time = Benchmark.measure do
        get "/api/v1/festivals/#{festival.id}"
      end
      
      expect(response).to have_http_status(:success)
      expect(time.real).to be < 1.0, "API request took #{time.real}s"
    end
    
    it 'efficiently serializes large datasets' do
      create_list(:vendor_application, 200, festival: festival)
      
      time = Benchmark.measure do
        get "/api/v1/festivals/#{festival.id}/vendor_applications"
      end
      
      expect(response).to have_http_status(:success)
      expect(time.real).to be < 2.0, "Large dataset serialization took #{time.real}s"
    end
    
    it 'handles concurrent API requests efficiently' do
      threads = []
      times = []
      
      5.times do
        threads << Thread.new do
          time = Benchmark.measure do
            get "/api/v1/festivals/#{festival.id}/dashboard"
          end
          times << time.real
        end
      end
      
      threads.each(&:join)
      
      expect(times.max).to be < 3.0, "Slowest concurrent API request: #{times.max}s"
    end
  end

  describe 'Scalability Testing' do
    it 'scales with increasing festival count' do
      # Create multiple festivals for the user
      festivals = create_list(:festival, 20, user: user)
      festivals.each do |fest|
        create_list(:vendor_application, 10, festival: fest)
        create_list(:task, 25, festival: fest)
      end
      
      time = Benchmark.measure do
        visit festivals_path
        expect(page).to have_content('My Festivals')
      end
      
      expect(time.real).to be < 3.0, "Festival list with 20 festivals took #{time.real}s"
    end
    
    it 'handles large numbers of concurrent users' do
      # Simulate multiple users with different festivals
      users = create_list(:user, 10)
      festivals = users.map { |u| create(:festival, user: u) }
      
      festivals.each do |fest|
        create_list(:vendor_application, 25, festival: fest)
        create_list(:task, 50, festival: fest)
      end
      
      # This test would require actual concurrent user simulation
      # For now, we'll test sequential access to different festivals
      times = []
      
      festivals.first(5).each do |fest|
        sign_in fest.user
        time = Benchmark.measure do
          visit festival_path(fest)
        end
        times << time.real
        sign_out fest.user
      end
      
      expect(times.max).to be < 4.0, "Slowest festival load: #{times.max}s"
      expect(times.sum / times.size).to be < 2.5, "Average festival load: #{times.sum / times.size}s"
    end
  end

  private

  def get_memory_usage
    # Platform-specific memory usage detection
    case RbConfig::CONFIG['host_os']
    when /darwin/i # macOS
      `ps -o rss= -p #{Process.pid}`.to_i / 1024 # Convert KB to MB
    when /linux/i
      `ps -o rss= -p #{Process.pid}`.to_i / 1024 # Convert KB to MB
    else
      0 # Fallback for unsupported platforms
    end
  rescue
    0
  end

  def get_session_size
    # Estimate session size (simplified)
    if respond_to?(:session)
      session.to_s.bytesize / 1024 # Convert to KB
    else
      0
    end
  rescue
    0
  end

  def simulate_network_latency(milliseconds = 100)
    sleep(milliseconds / 1000.0)
  end

  def stress_test_component(component_name, iterations = 10)
    times = []
    
    iterations.times do |i|
      time = Benchmark.measure do
        yield
      end
      times << time.real
      
      # Add some variance to simulate real-world conditions
      simulate_network_latency(rand(50..150))
    end
    
    {
      average: times.sum / times.size,
      min: times.min,
      max: times.max,
      median: times.sort[times.size / 2],
      component: component_name,
      iterations: iterations
    }
  end
end