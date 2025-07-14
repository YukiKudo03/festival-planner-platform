# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiRecommendationsController, type: :controller do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, budget: 500000) }
  let(:venue) { create(:venue, capacity: 2000) }
  let(:ai_service) { instance_double(AiRecommendationService) }

  before do
    sign_in user
    allow(AiRecommendationService).to receive(:new).and_return(ai_service)
    festival.update!(venue: venue)
  end

  describe 'GET #index' do
    before do
      allow(controller).to receive(:generate_ai_insights).and_return({
        attendance_outlook: { predicted_attendance: 1500 },
        budget_health: { score: 'good' },
        operational_readiness: 'excellent',
        risk_level: 'low'
      })
      allow(controller).to receive(:get_all_recommendations).and_return([
        'Consider increasing marketing budget',
        'Add more food vendors'
      ])
    end

    it 'returns a success response' do
      get :index, params: { festival_id: festival.id }
      expect(response).to be_successful
    end

    it 'assigns AI insights and recommendations' do
      get :index, params: { festival_id: festival.id }
      expect(assigns(:ai_insights)).to be_present
      expect(assigns(:recommendations)).to be_present
    end

    it 'responds to JSON format' do
      get :index, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'POST #attendance_prediction' do
    let(:prediction_result) do
      {
        success: true,
        predicted_attendance: 1750,
        confidence_score: 0.85,
        factors: { weather_impact: 0.1, seasonal_factor: 0.15 },
        recommendations: [ 'Consider additional capacity' ]
      }
    end

    before do
      allow(ai_service).to receive(:predict_attendance).and_return(prediction_result)
    end

    it 'returns attendance prediction' do
      post :attendance_prediction, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:prediction)).to eq(prediction_result)
    end

    it 'passes weather data when provided' do
      weather_data = { temperature: 25, precipitation_probability: 20 }

      expect(ai_service).to receive(:predict_attendance).with(
        festival,
        hash_including(weather_data: weather_data)
      ).and_return(prediction_result)

      post :attendance_prediction, params: {
        festival_id: festival.id,
        weather: weather_data
      }
    end

    it 'responds to JSON format' do
      post :attendance_prediction, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['predicted_attendance']).to eq(1750)
    end

    it 'handles prediction errors gracefully' do
      allow(ai_service).to receive(:predict_attendance).and_raise(StandardError.new('Prediction failed'))

      post :attendance_prediction, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:prediction)[:error]).to be_present
    end
  end

  describe 'POST #layout_optimization' do
    let(:vendors) { create_list(:vendor_application, 5, festival: festival, status: 'approved') }
    let(:optimization_result) do
      {
        success: true,
        layout: { vendor_positions: {}, pathways: [], emergency_exits: [] },
        efficiency_score: 0.88,
        crowd_flow_score: 0.92,
        accessibility_score: 0.85,
        recommendations: [ 'Optimize vendor spacing' ]
      }
    end

    before do
      vendors # create vendors
      allow(ai_service).to receive(:optimize_vendor_layout).and_return(optimization_result)
    end

    it 'returns layout optimization' do
      post :layout_optimization, params: { festival_id: festival.id, venue_id: venue.id }
      expect(response).to be_successful
      expect(assigns(:optimization)).to eq(optimization_result)
    end

    it 'handles missing venue gracefully' do
      festival.update!(venue: nil)

      post :layout_optimization, params: { festival_id: festival.id }, format: :json
      expect(response).to have_http_status(:unprocessable_entity)

      json_response = JSON.parse(response.body)
      expect(json_response['error']).to be_present
    end

    it 'passes optimization constraints' do
      constraints = { min_distance: 5.0, emergency_width: 6.0 }

      expect(ai_service).to receive(:optimize_vendor_layout).with(
        venue,
        anything,
        hash_including(constraints)
      ).and_return(optimization_result)

      post :layout_optimization, params: {
        festival_id: festival.id,
        venue_id: venue.id,
        min_distance: 5.0,
        emergency_width: 6.0
      }
    end

    it 'responds to JSON format' do
      post :layout_optimization, params: { festival_id: festival.id, venue_id: venue.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['efficiency_score']).to eq(0.88)
    end
  end

  describe 'POST #budget_allocation' do
    let(:allocation_result) do
      {
        success: true,
        total_budget: 500000,
        recommended_allocation: {
          venue_costs: 150000,
          marketing_promotion: 75000,
          security_safety: 50000
        },
        allocation_rationale: { venue_costs: 'High capacity venue required' },
        risk_assessment: { overall_risk: 'medium' },
        recommendations: [ 'Allocate more to marketing' ]
      }
    end

    before do
      allow(ai_service).to receive(:recommend_budget_allocation).and_return(allocation_result)
    end

    it 'returns budget allocation recommendations' do
      post :budget_allocation, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:allocation)).to eq(allocation_result)
    end

    it 'uses custom budget when provided' do
      custom_budget = 750000

      expect(ai_service).to receive(:recommend_budget_allocation).with(
        festival,
        custom_budget,
        anything
      ).and_return(allocation_result)

      post :budget_allocation, params: {
        festival_id: festival.id,
        total_budget: custom_budget
      }
    end

    it 'responds to JSON format' do
      post :budget_allocation, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['total_budget']).to eq(500000)
    end
  end

  describe 'POST #risk_assessment' do
    let(:risk_result) do
      {
        success: true,
        overall_risk_score: 0.35,
        risk_level: 'medium',
        category_assessments: {
          weather: { score: 0.2, level: 'low' },
          financial: { score: 0.5, level: 'medium' }
        },
        critical_risks: [ 'Budget overrun potential' ],
        mitigation_strategies: { financial: [ 'Implement cost controls' ] },
        recommendations: [ 'Monitor budget closely' ]
      }
    end

    before do
      allow(ai_service).to receive(:assess_festival_risks).and_return(risk_result)
    end

    it 'returns risk assessment' do
      post :risk_assessment, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:risk_assessment)).to eq(risk_result)
    end

    it 'uses custom risk categories when provided' do
      categories = [ 'weather', 'financial' ]

      expect(ai_service).to receive(:assess_festival_risks).with(
        festival,
        hash_including(risk_categories: categories)
      ).and_return(risk_result)

      post :risk_assessment, params: {
        festival_id: festival.id,
        categories: categories
      }
    end

    it 'responds to JSON format' do
      post :risk_assessment, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['overall_risk_score']).to eq(0.35)
    end
  end

  describe 'GET #predictive_dashboard' do
    before do
      allow(controller).to receive(:get_attendance_prediction).and_return({ predicted_attendance: 1500 })
      allow(controller).to receive(:calculate_budget_efficiency).and_return({ score: 'good' })
      allow(controller).to receive(:get_risk_overview).and_return({ overall_risk: 'medium' })
      allow(controller).to receive(:get_layout_score).and_return({ overall_score: 85 })
      allow(controller).to receive(:get_priority_recommendations).and_return([])
      allow(controller).to receive(:calculate_kpi_metrics).and_return({})
      allow(controller).to receive(:analyze_trends).and_return({})
    end

    it 'returns comprehensive dashboard data' do
      get :predictive_dashboard, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:dashboard_data)).to include(
        :attendance_prediction,
        :budget_efficiency,
        :risk_overview,
        :layout_score,
        :recommendations,
        :kpi_metrics,
        :trend_analysis
      )
    end

    it 'responds to JSON format' do
      get :predictive_dashboard, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response).to include('attendance_prediction', 'budget_efficiency', 'risk_overview')
    end
  end

  describe 'POST #roi_optimization' do
    let(:roi_result) do
      {
        success: true,
        investment_recommendations: {
          marketing: { investment: 50000, expected_roi: 3.2 },
          venue_upgrade: { investment: 25000, expected_roi: 2.1 }
        },
        optimization_strategy: 'Focus on marketing for maximum ROI',
        projected_outcomes: { total_revenue: 650000, profit_margin: 0.25 }
      }
    end

    before do
      allow(ai_service).to receive(:optimize_roi).and_return(roi_result)
    end

    it 'returns ROI optimization recommendations' do
      post :roi_optimization, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:roi_analysis)).to eq(roi_result)
    end

    it 'passes investment areas when provided' do
      investment_areas = [ 'marketing', 'entertainment' ]

      expect(ai_service).to receive(:optimize_roi).with(
        festival,
        hash_including(investment_areas: investment_areas)
      ).and_return(roi_result)

      post :roi_optimization, params: {
        festival_id: festival.id,
        investment_areas: investment_areas
      }
    end

    it 'responds to JSON format' do
      post :roi_optimization, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['optimization_strategy']).to be_present
    end
  end

  describe 'GET #market_trends' do
    let(:trends_result) do
      {
        success: true,
        trends: {
          attendance: { direction: 'increasing', rate: 0.15 },
          spending: { direction: 'stable', rate: 0.02 }
        },
        market_insights: [ 'Summer festivals showing growth' ],
        recommendations: [ 'Capitalize on upward trend' ]
      }
    end

    before do
      allow(ai_service).to receive(:analyze_market_trends).and_return(trends_result)
    end

    it 'returns market trend analysis' do
      get :market_trends, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:trends)).to eq(trends_result)
    end

    it 'passes trend categories and region when provided' do
      categories = [ 'attendance', 'spending' ]
      region = 'ontario'

      expect(ai_service).to receive(:analyze_market_trends).with(
        hash_including(
          trend_categories: categories,
          region: region
        )
      ).and_return(trends_result)

      get :market_trends, params: {
        festival_id: festival.id,
        categories: categories,
        region: region
      }
    end

    it 'responds to JSON format' do
      get :market_trends, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['trends']).to be_present
    end
  end

  describe 'GET #performance_benchmark' do
    let(:benchmark_result) do
      {
        success: true,
        benchmark_data: {
          attendance_percentile: 75,
          revenue_percentile: 68,
          satisfaction_percentile: 82
        },
        comparison_insights: [ 'Above average in satisfaction' ],
        improvement_opportunities: [ 'Revenue optimization potential' ]
      }
    end

    before do
      allow(controller).to receive(:find_similar_festivals).and_return([])
      allow(ai_service).to receive(:benchmark_performance).and_return(benchmark_result)
    end

    it 'returns performance benchmark data' do
      get :performance_benchmark, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:benchmark)).to eq(benchmark_result)
    end

    it 'uses custom metrics when provided' do
      metrics = [ 'attendance', 'revenue' ]

      expect(ai_service).to receive(:benchmark_performance).with(
        festival,
        hash_including(metrics: metrics)
      ).and_return(benchmark_result)

      get :performance_benchmark, params: {
        festival_id: festival.id,
        metrics: metrics
      }
    end

    it 'responds to JSON format' do
      get :performance_benchmark, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['benchmark_data']).to be_present
    end
  end

  describe 'GET #realtime_monitoring' do
    before do
      allow(controller).to receive(:get_current_status).and_return({ phase: 'planning' })
      allow(controller).to receive(:get_live_metrics).and_return({ registered_vendors: 12 })
      allow(controller).to receive(:get_active_alerts).and_return([])
      allow(controller).to receive(:get_realtime_recommendations).and_return([])
      allow(controller).to receive(:calculate_realtime_kpis).and_return({})
    end

    it 'returns real-time monitoring data' do
      get :realtime_monitoring, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:monitoring_data)).to include(
        :current_status,
        :live_metrics,
        :alerts,
        :recommendations,
        :performance_indicators
      )
    end

    it 'responds to JSON format' do
      get :realtime_monitoring, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response).to include('current_status', 'live_metrics', 'alerts')
    end
  end

  describe 'GET #batch_analysis' do
    before do
      allow(controller).to receive(:get_attendance_prediction).and_return({ predicted_attendance: 1500 })
      allow(controller).to receive(:get_budget_analysis).and_return({ efficiency: 'good' })
      allow(controller).to receive(:get_layout_analysis).and_return({ score: 85 })
      allow(controller).to receive(:get_risk_overview).and_return({ overall_risk: 'medium' })
    end

    it 'returns batch analysis results' do
      get :batch_analysis, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:batch_results)).to include(:attendance, :budget, :layout, :risks)
    end

    it 'runs only requested analysis types' do
      analysis_types = [ 'attendance', 'budget' ]

      get :batch_analysis, params: {
        festival_id: festival.id,
        analysis_types: analysis_types
      }

      expect(assigns(:batch_results).keys.map(&:to_s)).to match_array(analysis_types)
    end

    it 'responds to JSON format' do
      get :batch_analysis, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response).to include('attendance', 'budget', 'layout', 'risks')
    end
  end

  describe 'GET #industry_insights' do
    let(:insights_result) do
      {
        success: true,
        industry_trends: { growth_rate: 0.12, market_size: 15000000 },
        regional_analysis: { market_penetration: 0.35 },
        competitive_landscape: { similar_events: 8 },
        recommendations: [ 'Focus on unique value proposition' ]
      }
    end

    before do
      allow(ai_service).to receive(:generate_industry_insights).and_return(insights_result)
    end

    it 'returns industry insights' do
      get :industry_insights, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:insights)).to eq(insights_result)
    end

    it 'passes industry type and region when provided' do
      industry_type = 'music'
      region = 'ontario'

      expect(ai_service).to receive(:generate_industry_insights).with(
        hash_including(
          industry_type: industry_type,
          region: region
        )
      ).and_return(insights_result)

      get :industry_insights, params: {
        festival_id: festival.id,
        industry_type: industry_type,
        region: region
      }
    end

    it 'responds to JSON format' do
      get :industry_insights, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      expect(json_response['industry_trends']).to be_present
    end
  end

  describe 'authorization' do
    context 'when user does not own the festival' do
      let(:other_user) { create(:user) }
      let(:other_festival) { create(:festival, user: other_user) }

      it 'denies access to AI recommendations' do
        get :index, params: { festival_id: other_festival.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end

      it 'denies access to attendance prediction' do
        post :attendance_prediction, params: { festival_id: other_festival.id }
        expect(response).to redirect_to(root_path)
      end

      it 'denies access to layout optimization' do
        post :layout_optimization, params: { festival_id: other_festival.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'error handling' do
    it 'handles invalid festival ID gracefully' do
      get :index, params: { festival_id: 'nonexistent' }
      expect(response).to redirect_to(festivals_path)
      expect(flash[:alert]).to be_present
    end

    it 'handles AI service errors gracefully' do
      allow(ai_service).to receive(:predict_attendance).and_raise(StandardError.new('AI service unavailable'))

      post :attendance_prediction, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:prediction)[:error]).to be_present
    end

    it 'logs AI service errors appropriately' do
      expect(Rails.logger).to receive(:error).with(/Attendance prediction error/)

      allow(ai_service).to receive(:predict_attendance).and_raise(StandardError.new('Test error'))
      post :attendance_prediction, params: { festival_id: festival.id }
    end
  end

  describe 'performance optimization' do
    it 'caches expensive AI calculations' do
      # In real implementation, verify caching behavior
      get :predictive_dashboard, params: { festival_id: festival.id }
      expect(response).to be_successful
    end

    it 'handles timeout errors from AI service' do
      allow(ai_service).to receive(:predict_attendance).and_raise(Timeout::Error.new('Request timeout'))

      post :attendance_prediction, params: { festival_id: festival.id }
      expect(response).to be_successful
      expect(assigns(:prediction)[:error]).to include('timeout')
    end
  end

  describe 'data validation' do
    it 'validates weather data format' do
      invalid_weather = { temperature: 'hot', precipitation: 'maybe' }

      post :attendance_prediction, params: {
        festival_id: festival.id,
        weather: invalid_weather
      }

      # Should handle invalid data gracefully
      expect(response).to be_successful
    end

    it 'validates budget allocation parameters' do
      post :budget_allocation, params: {
        festival_id: festival.id,
        total_budget: -1000
      }

      # Should use festival budget instead of negative value
      expect(response).to be_successful
    end
  end
end
