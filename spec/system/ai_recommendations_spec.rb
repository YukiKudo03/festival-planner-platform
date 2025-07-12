# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Recommendations System', type: :system do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, budget: 500000) }
  let(:venue) { create(:venue, capacity: 2000) }
  
  before do
    festival.update!(venue: venue)
    create_list(:vendor_application, 5, festival: festival, status: 'approved')
    sign_in user
  end

  describe 'AI Recommendations Dashboard' do
    it 'displays comprehensive AI insights' do
      visit festival_ai_recommendations_path(festival)
      
      expect(page).to have_content('AI Recommendations')
      expect(page).to have_content('Attendance Outlook')
      expect(page).to have_content('Budget Health')
      expect(page).to have_content('Operational Readiness')
      expect(page).to have_content('Risk Level')
    end
    
    it 'shows actionable recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      within('.recommendations-section') do
        expect(page).to have_css('.recommendation-item')
        expect(page).to have_content('Recommendation')
      end
    end
    
    it 'displays real-time metrics' do
      visit festival_ai_recommendations_path(festival)
      
      expect(page).to have_content('Task Completion Rate')
      expect(page).to have_content('Budget Adherence')
      expect(page).to have_content('Vendor Count')
    end
  end

  describe 'Attendance Prediction' do
    it 'generates attendance predictions with weather data' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Attendance Prediction'
      
      fill_in 'Temperature', with: '25'
      fill_in 'Precipitation Probability', with: '20'
      select 'Sunny', from: 'Weather Condition'
      
      click_button 'Generate Prediction'
      
      expect(page).to have_content('Predicted Attendance')
      expect(page).to have_content('Confidence Score')
      expect(page).to have_content('Weather Impact')
    end
    
    it 'shows historical comparison' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Attendance Prediction'
      click_button 'Generate Prediction'
      
      within('.historical-comparison') do
        expect(page).to have_content('Previous Years')
        expect(page).to have_content('Trend Analysis')
      end
    end
    
    it 'provides attendance optimization recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Attendance Prediction'
      click_button 'Generate Prediction'
      
      within('.prediction-recommendations') do
        expect(page).to have_css('.recommendation-card')
        expect(page).to have_content('Marketing Strategy')
      end
    end
  end

  describe 'Layout Optimization' do
    it 'optimizes vendor layout automatically' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Layout Optimization'
      
      select venue.name, from: 'Venue'
      click_button 'Optimize Layout'
      
      expect(page).to have_content('Layout Optimization Results')
      expect(page).to have_content('Efficiency Score')
      expect(page).to have_content('Crowd Flow Score')
      expect(page).to have_content('Accessibility Score')
    end
    
    it 'displays visual layout representation' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Layout Optimization'
      click_button 'Optimize Layout'
      
      within('.layout-visualization') do
        expect(page).to have_css('.vendor-position')
        expect(page).to have_css('.pathway')
        expect(page).to have_css('.emergency-exit')
      end
    end
    
    it 'allows custom optimization constraints' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Layout Optimization'
      
      fill_in 'Minimum Distance Between Vendors', with: '5.0'
      fill_in 'Emergency Access Width', with: '6.0'
      
      click_button 'Optimize Layout'
      
      expect(page).to have_content('Custom constraints applied')
    end
    
    it 'provides alternative layout options' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Layout Optimization'
      click_button 'Optimize Layout'
      
      within('.alternative-layouts') do
        expect(page).to have_content('Alternative Layout 1')
        expect(page).to have_content('Alternative Layout 2')
        expect(page).to have_button('Select This Layout')
      end
    end
  end

  describe 'Budget Allocation Recommendations' do
    it 'suggests optimal budget distribution' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Budget Allocation'
      
      fill_in 'Total Budget', with: '600000'
      click_button 'Generate Allocation'
      
      expect(page).to have_content('Recommended Budget Allocation')
      expect(page).to have_content('Venue Costs')
      expect(page).to have_content('Marketing Promotion')
      expect(page).to have_content('Security & Safety')
      expect(page).to have_content('Contingency')
    end
    
    it 'shows allocation rationale' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Budget Allocation'
      click_button 'Generate Allocation'
      
      within('.allocation-rationale') do
        expect(page).to have_content('Why this allocation?')
        expect(page).to have_content('Based on historical data')
      end
    end
    
    it 'includes risk assessment in budget planning' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Budget Allocation'
      click_button 'Generate Allocation'
      
      within('.risk-assessment') do
        expect(page).to have_content('Budget Risk Analysis')
        expect(page).to have_content('Contingency Plan')
      end
    end
    
    it 'allows budget scenario comparison' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Budget Allocation'
      
      click_button 'Compare Scenarios'
      
      expect(page).to have_content('Conservative Scenario')
      expect(page).to have_content('Aggressive Scenario')
      expect(page).to have_content('Balanced Scenario')
    end
  end

  describe 'Risk Assessment' do
    it 'performs comprehensive risk analysis' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Risk Assessment'
      
      check 'Weather Risks'
      check 'Financial Risks'
      check 'Operational Risks'
      check 'Safety Risks'
      
      click_button 'Assess Risks'
      
      expect(page).to have_content('Overall Risk Score')
      expect(page).to have_content('Risk Level')
      expect(page).to have_content('Critical Risks')
    end
    
    it 'shows detailed risk categories' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Risk Assessment'
      click_button 'Assess Risks'
      
      within('.risk-categories') do
        expect(page).to have_content('Weather Risk')
        expect(page).to have_content('Financial Risk')
        expect(page).to have_content('Operational Risk')
        expect(page).to have_content('Safety Risk')
      end
    end
    
    it 'provides mitigation strategies' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Risk Assessment'
      click_button 'Assess Risks'
      
      within('.mitigation-strategies') do
        expect(page).to have_content('Recommended Actions')
        expect(page).to have_content('Prevention Measures')
        expect(page).to have_content('Contingency Plans')
      end
    end
    
    it 'displays risk monitoring recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Risk Assessment'
      click_button 'Assess Risks'
      
      within('.monitoring-recommendations') do
        expect(page).to have_content('Monitor Daily')
        expect(page).to have_content('Monitor Weekly')
        expect(page).to have_content('Alert Thresholds')
      end
    end
  end

  describe 'Predictive Dashboard' do
    it 'shows comprehensive predictive analytics' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Predictive Dashboard'
      
      expect(page).to have_content('Predictive Analytics Dashboard')
      expect(page).to have_content('Attendance Forecast')
      expect(page).to have_content('Budget Efficiency')
      expect(page).to have_content('Risk Overview')
      expect(page).to have_content('Layout Score')
    end
    
    it 'displays KPI metrics with trends' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Predictive Dashboard'
      
      within('.kpi-metrics') do
        expect(page).to have_content('Task Completion Rate')
        expect(page).to have_content('Vendor Satisfaction')
        expect(page).to have_content('Budget Adherence')
        expect(page).to have_css('.trend-indicator')
      end
    end
    
    it 'shows priority recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Predictive Dashboard'
      
      within('.priority-recommendations') do
        expect(page).to have_content('High Priority')
        expect(page).to have_content('Medium Priority')
        expect(page).to have_css('.recommendation-priority-badge')
      end
    end
    
    it 'updates metrics in real-time', js: true do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Predictive Dashboard'
      
      # Simulate real-time updates
      expect(page).to have_css('.metric-value')
      
      # Check for auto-refresh functionality
      expect(page).to have_css('[data-refresh="auto"]')
    end
  end

  describe 'ROI Optimization' do
    it 'analyzes return on investment opportunities' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'ROI Optimization'
      
      check 'Marketing Investment'
      check 'Venue Upgrade'
      check 'Entertainment Enhancement'
      
      select '6 months', from: 'Time Horizon'
      
      click_button 'Analyze ROI'
      
      expect(page).to have_content('ROI Analysis Results')
      expect(page).to have_content('Investment Recommendations')
      expect(page).to have_content('Expected Return')
    end
    
    it 'compares investment scenarios' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'ROI Optimization'
      click_button 'Analyze ROI'
      
      within('.investment-scenarios') do
        expect(page).to have_content('Conservative Investment')
        expect(page).to have_content('Moderate Investment')
        expect(page).to have_content('Aggressive Investment')
      end
    end
    
    it 'shows projected financial outcomes' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'ROI Optimization'
      click_button 'Analyze ROI'
      
      within('.projected-outcomes') do
        expect(page).to have_content('Projected Revenue')
        expect(page).to have_content('Profit Margin')
        expect(page).to have_content('Break-even Point')
      end
    end
  end

  describe 'Market Trends Analysis' do
    it 'displays industry market trends' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Market Trends'
      
      select 'Ontario', from: 'Region'
      select '12 months', from: 'Time Period'
      
      click_button 'Analyze Trends'
      
      expect(page).to have_content('Market Trends Analysis')
      expect(page).to have_content('Attendance Trends')
      expect(page).to have_content('Spending Trends')
      expect(page).to have_content('Preference Trends')
    end
    
    it 'shows competitive landscape' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Market Trends'
      click_button 'Analyze Trends'
      
      within('.competitive-landscape') do
        expect(page).to have_content('Similar Events')
        expect(page).to have_content('Market Share')
        expect(page).to have_content('Competitive Advantages')
      end
    end
    
    it 'provides market-based recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Market Trends'
      click_button 'Analyze Trends'
      
      within('.market-recommendations') do
        expect(page).to have_content('Market Opportunities')
        expect(page).to have_content('Positioning Strategy')
        expect(page).to have_content('Competitive Response')
      end
    end
  end

  describe 'Performance Benchmarking' do
    it 'benchmarks against similar festivals' do
      # Create similar festivals for comparison
      create_list(:festival, 3, budget: festival.budget)
      
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Performance Benchmark'
      
      check 'Attendance'
      check 'Revenue'
      check 'Satisfaction'
      
      click_button 'Benchmark Performance'
      
      expect(page).to have_content('Performance Benchmark Results')
      expect(page).to have_content('Percentile Ranking')
      expect(page).to have_content('Comparison Insights')
    end
    
    it 'shows improvement opportunities' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Performance Benchmark'
      click_button 'Benchmark Performance'
      
      within('.improvement-opportunities') do
        expect(page).to have_content('Areas for Improvement')
        expect(page).to have_content('Best Practices')
        expect(page).to have_content('Action Items')
      end
    end
    
    it 'displays peer comparison charts' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Performance Benchmark'
      click_button 'Benchmark Performance'
      
      expect(page).to have_css('.benchmark-chart')
      expect(page).to have_css('.percentile-indicator')
    end
  end

  describe 'Real-time Monitoring' do
    it 'shows live festival metrics', js: true do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Real-time Monitoring'
      
      expect(page).to have_content('Real-time Festival Monitoring')
      expect(page).to have_content('Current Status')
      expect(page).to have_content('Live Metrics')
      expect(page).to have_content('Active Alerts')
    end
    
    it 'displays current festival phase' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Real-time Monitoring'
      
      within('.current-status') do
        expect(page).to have_content('Festival Phase')
        expect(page).to have_content('Days Remaining')
        expect(page).to have_content('Completion Percentage')
      end
    end
    
    it 'shows active alerts and warnings' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Real-time Monitoring'
      
      within('.active-alerts') do
        expect(page).to have_css('.alert-item')
        expect(page).to have_content('Budget Utilization')
      end
    end
    
    it 'provides real-time recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Real-time Monitoring'
      
      within('.realtime-recommendations') do
        expect(page).to have_content('Immediate Actions')
        expect(page).to have_content('Urgent Items')
      end
    end
  end

  describe 'Batch Analysis' do
    it 'runs multiple analyses simultaneously' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Batch Analysis'
      
      check 'Attendance Analysis'
      check 'Budget Analysis'
      check 'Layout Analysis'
      check 'Risk Analysis'
      
      click_button 'Run Batch Analysis'
      
      expect(page).to have_content('Batch Analysis Results')
      expect(page).to have_content('Attendance Results')
      expect(page).to have_content('Budget Results')
      expect(page).to have_content('Layout Results')
      expect(page).to have_content('Risk Results')
    end
    
    it 'provides comprehensive summary' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Batch Analysis'
      click_button 'Run Batch Analysis'
      
      within('.analysis-summary') do
        expect(page).to have_content('Overall Assessment')
        expect(page).to have_content('Key Findings')
        expect(page).to have_content('Priority Actions')
      end
    end
    
    it 'allows export of analysis results' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Batch Analysis'
      click_button 'Run Batch Analysis'
      
      expect(page).to have_link('Export to PDF')
      expect(page).to have_link('Export to CSV')
      expect(page).to have_link('Export to Excel')
    end
  end

  describe 'Industry Insights' do
    it 'provides industry-wide analysis' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Industry Insights'
      
      select 'Music Festivals', from: 'Industry Type'
      select 'Ontario', from: 'Region'
      select 'Standard', from: 'Analysis Depth'
      
      click_button 'Generate Insights'
      
      expect(page).to have_content('Industry Insights')
      expect(page).to have_content('Market Trends')
      expect(page).to have_content('Regional Analysis')
      expect(page).to have_content('Competitive Landscape')
    end
    
    it 'shows growth opportunities' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Industry Insights'
      click_button 'Generate Insights'
      
      within('.growth-opportunities') do
        expect(page).to have_content('Market Gaps')
        expect(page).to have_content('Emerging Trends')
        expect(page).to have_content('Investment Areas')
      end
    end
    
    it 'provides strategic recommendations' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Industry Insights'
      click_button 'Generate Insights'
      
      within('.strategic-recommendations') do
        expect(page).to have_content('Market Positioning')
        expect(page).to have_content('Competitive Strategy')
        expect(page).to have_content('Growth Strategy')
      end
    end
  end

  describe 'Error Handling and Edge Cases' do
    it 'handles AI service unavailability gracefully' do
      # Simulate AI service error
      allow_any_instance_of(AiRecommendationService).to receive(:predict_attendance).and_raise(StandardError.new('Service unavailable'))
      
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Attendance Prediction'
      click_button 'Generate Prediction'
      
      expect(page).to have_content('Unable to generate prediction')
      expect(page).to have_content('Please try again later')
    end
    
    it 'validates input parameters' do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Budget Allocation'
      
      fill_in 'Total Budget', with: '-1000'
      click_button 'Generate Allocation'
      
      expect(page).to have_content('Budget must be positive')
    end
    
    it 'shows loading states during analysis', js: true do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Attendance Prediction'
      click_button 'Generate Prediction'
      
      expect(page).to have_css('.loading-spinner')
      expect(page).to have_content('Analyzing data...')
    end
  end

  describe 'Mobile Responsiveness' do
    it 'displays properly on mobile devices', driver: :mobile do
      visit festival_ai_recommendations_path(festival)
      
      expect(page).to have_css('.mobile-optimized')
      expect(page).to have_content('AI Recommendations')
      
      # Test mobile navigation
      click_button 'Menu'
      expect(page).to have_css('.mobile-menu')
    end
    
    it 'adapts charts for mobile viewing', driver: :mobile do
      visit festival_ai_recommendations_path(festival)
      
      click_link 'Predictive Dashboard'
      
      expect(page).to have_css('.mobile-chart')
      expect(page).to have_css('.responsive-visualization')
    end
  end

  describe 'Accessibility' do
    it 'provides proper ARIA labels and keyboard navigation' do
      visit festival_ai_recommendations_path(festival)
      
      expect(page).to have_css('[aria-label]')
      expect(page).to have_css('[role="button"]')
      expect(page).to have_css('[tabindex]')
    end
    
    it 'supports screen readers with descriptive text' do
      visit festival_ai_recommendations_path(festival)
      
      expect(page).to have_css('.sr-only')
      expect(page).to have_content('Screen reader description')
    end
  end
end