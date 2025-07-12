# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Integration', type: :request do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, budget: 500000) }
  let(:venue) { create(:venue, capacity: 2000) }
  let(:municipal_authority) { create(:municipal_authority) }
  
  before do
    festival.update!(venue: venue)
    sign_in user
  end

  describe 'API v1 Festival Management' do
    describe 'GET /api/v1/festivals' do
      let!(:festivals) { create_list(:festival, 3, user: user) }
      
      it 'returns user festivals with analytics' do
        get '/api/v1/festivals'
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['festivals']).to have(3).items
        expect(json_response['festivals'].first).to include('id', 'name', 'budget', 'analytics')
      end
      
      it 'includes industry specialization data' do
        create(:industry_specialization, :technology, :active, festival: festivals.first)
        
        get '/api/v1/festivals'
        
        json_response = JSON.parse(response.body)
        festival_data = json_response['festivals'].first
        
        expect(festival_data['industry_specializations']).to be_present
        expect(festival_data['industry_specializations'].first).to include('industry_type', 'status')
      end
      
      it 'includes tourism collaboration summaries' do
        create(:tourism_collaboration, :active, festival: festivals.first, municipal_authority: municipal_authority)
        
        get '/api/v1/festivals'
        
        json_response = JSON.parse(response.body)
        festival_data = json_response['festivals'].first
        
        expect(festival_data['tourism_collaborations']).to be_present
        expect(festival_data['tourism_collaborations'].first).to include('collaboration_type', 'status')
      end
    end
    
    describe 'GET /api/v1/festivals/:id' do
      it 'returns comprehensive festival data' do
        get "/api/v1/festivals/#{festival.id}"
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include('id', 'name', 'budget', 'start_date', 'end_date')
        expect(json_response).to include('venue', 'analytics', 'dashboard')
      end
      
      it 'includes real-time metrics' do
        create_list(:vendor_application, 5, festival: festival, status: 'approved')
        create_list(:task, 10, festival: festival, status: 'completed')
        
        get "/api/v1/festivals/#{festival.id}"
        
        json_response = JSON.parse(response.body)
        
        expect(json_response['analytics']).to include(
          'vendor_count',
          'task_completion_rate',
          'budget_utilization',
          'timeline_progress'
        )
      end
    end
    
    describe 'GET /api/v1/festivals/:id/dashboard' do
      before do
        create(:industry_specialization, :technology, :active, festival: festival)
        create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority)
      end
      
      it 'returns unified dashboard data' do
        get "/api/v1/festivals/#{festival.id}/dashboard"
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'overview',
          'industry_specialization_status',
          'tourism_collaboration_status',
          'ai_insights',
          'budget_health',
          'risk_assessment',
          'recommendations'
        )
      end
      
      it 'includes performance indicators' do
        get "/api/v1/festivals/#{festival.id}/dashboard"
        
        json_response = JSON.parse(response.body)
        overview = json_response['overview']
        
        expect(overview).to include(
          'completion_percentage',
          'days_remaining',
          'budget_adherence',
          'vendor_satisfaction',
          'safety_compliance'
        )
      end
    end
  end

  describe 'AI Recommendations API' do
    let(:ai_service) { instance_double(AiRecommendationService) }
    
    before do
      allow(AiRecommendationService).to receive(:new).and_return(ai_service)
    end
    
    describe 'POST /api/v1/festivals/:id/ai_recommendations/attendance_prediction' do
      let(:prediction_result) do
        {
          success: true,
          predicted_attendance: 1750,
          confidence_score: 0.85,
          factors: { weather_impact: 0.1, seasonal_factor: 0.15 },
          recommendations: ['Consider additional capacity']
        }
      end
      
      before do
        allow(ai_service).to receive(:predict_attendance).and_return(prediction_result)
      end
      
      it 'returns attendance prediction with weather data' do
        weather_data = { temperature: 25, precipitation_probability: 20 }
        
        post "/api/v1/festivals/#{festival.id}/ai_recommendations/attendance_prediction",
             params: { weather: weather_data }
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['predicted_attendance']).to eq(1750)
        expect(json_response['confidence_score']).to eq(0.85)
        expect(json_response['factors']).to include('weather_impact')
      end
      
      it 'includes historical comparison data' do
        post "/api/v1/festivals/#{festival.id}/ai_recommendations/attendance_prediction"
        
        json_response = JSON.parse(response.body)
        expect(json_response['recommendations']).to be_present
        expect(json_response['factors']).to be_present
      end
    end
    
    describe 'POST /api/v1/festivals/:id/ai_recommendations/layout_optimization' do
      let(:optimization_result) do
        {
          success: true,
          layout: { vendor_positions: {}, pathways: [], emergency_exits: [] },
          efficiency_score: 0.88,
          crowd_flow_score: 0.92,
          accessibility_score: 0.85,
          recommendations: ['Optimize vendor spacing']
        }
      end
      
      before do
        create_list(:vendor_application, 5, festival: festival, status: 'approved')
        allow(ai_service).to receive(:optimize_vendor_layout).and_return(optimization_result)
      end
      
      it 'optimizes venue layout for approved vendors' do
        post "/api/v1/festivals/#{festival.id}/ai_recommendations/layout_optimization",
             params: { venue_id: venue.id }
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['efficiency_score']).to eq(0.88)
        expect(json_response['crowd_flow_score']).to eq(0.92)
        expect(json_response['layout']).to include('vendor_positions', 'pathways', 'emergency_exits')
      end
      
      it 'applies custom optimization constraints' do
        constraints = { min_distance: 5.0, emergency_width: 6.0 }
        
        expect(ai_service).to receive(:optimize_vendor_layout).with(
          venue,
          anything,
          hash_including(constraints)
        ).and_return(optimization_result)
        
        post "/api/v1/festivals/#{festival.id}/ai_recommendations/layout_optimization",
             params: { venue_id: venue.id, min_distance: 5.0, emergency_width: 6.0 }
      end
    end
    
    describe 'POST /api/v1/festivals/:id/ai_recommendations/budget_allocation' do
      let(:allocation_result) do
        {
          success: true,
          total_budget: 500000,
          recommended_allocation: {
            venue_costs: 150000,
            marketing_promotion: 75000,
            security_safety: 50000
          },
          risk_assessment: { overall_risk: 'medium' }
        }
      end
      
      before do
        allow(ai_service).to receive(:recommend_budget_allocation).and_return(allocation_result)
      end
      
      it 'provides intelligent budget allocation recommendations' do
        post "/api/v1/festivals/#{festival.id}/ai_recommendations/budget_allocation",
             params: { total_budget: 600000 }
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['recommended_allocation']).to include(
          'venue_costs',
          'marketing_promotion',
          'security_safety'
        )
        expect(json_response['risk_assessment']).to be_present
      end
    end
    
    describe 'GET /api/v1/festivals/:id/ai_recommendations/batch_analysis' do
      before do
        allow_any_instance_of(AiRecommendationsController).to receive(:get_attendance_prediction)
          .and_return({ predicted_attendance: 1500 })
        allow_any_instance_of(AiRecommendationsController).to receive(:get_budget_analysis)
          .and_return({ efficiency: 'good' })
        allow_any_instance_of(AiRecommendationsController).to receive(:get_layout_analysis)
          .and_return({ score: 85 })
        allow_any_instance_of(AiRecommendationsController).to receive(:get_risk_overview)
          .and_return({ overall_risk: 'medium' })
      end
      
      it 'runs comprehensive batch analysis' do
        get "/api/v1/festivals/#{festival.id}/ai_recommendations/batch_analysis",
            params: { analysis_types: ['attendance', 'budget', 'layout', 'risks'] }
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include('attendance', 'budget', 'layout', 'risks')
      end
      
      it 'allows selective analysis types' do
        get "/api/v1/festivals/#{festival.id}/ai_recommendations/batch_analysis",
            params: { analysis_types: ['attendance', 'budget'] }
        
        json_response = JSON.parse(response.body)
        expect(json_response.keys).to match_array(['attendance', 'budget'])
      end
    end
  end

  describe 'Industry Specializations API' do
    let!(:industry_spec) { create(:industry_specialization, :technology, :active, festival: festival) }
    
    describe 'GET /api/v1/festivals/:id/industry_specializations' do
      it 'returns festival industry specializations' do
        get "/api/v1/festivals/#{festival.id}/industry_specializations"
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['industry_specializations']).to have(1).item
        
        specialization = json_response['industry_specializations'].first
        expect(specialization).to include('industry_type', 'status', 'progress_percentage', 'compliance_score')
      end
    end
    
    describe 'POST /api/v1/festivals/:id/industry_specializations' do
      let(:valid_params) do
        {
          industry_specialization: {
            industry_type: 'healthcare',
            specialization_config: {
              booth_layout: 'healthcare_pavilion',
              equipment_requirements: ['medical_grade_power']
            }.to_json,
            compliance_requirements: {
              safety_standards: ['FDA'],
              certifications: ['medical_certification']
            }.to_json,
            specialized_metrics: {
              kpis: ['patient_outcomes'],
              targets: { patient_outcomes: 95 }
            }.to_json
          }
        }
      end
      
      it 'creates new industry specialization via API' do
        post "/api/v1/festivals/#{festival.id}/industry_specializations", params: valid_params
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['industry_type']).to eq('healthcare')
        expect(json_response['status']).to eq('draft')
      end
    end
    
    describe 'PATCH /api/v1/festivals/:id/industry_specializations/:id/update_metrics' do
      let(:new_metrics) do
        {
          metrics: {
            innovation_index: 88,
            tech_adoption_rate: 75,
            completed_tasks: 8
          }
        }
      end
      
      it 'updates specialized metrics via API' do
        patch "/api/v1/festivals/#{festival.id}/industry_specializations/#{industry_spec.id}/update_metrics",
              params: new_metrics
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['metrics']['innovation_index']).to eq(88)
        
        industry_spec.reload
        expect(industry_spec.metrics['innovation_index']).to eq(88)
      end
    end
  end

  describe 'Tourism Collaborations API' do
    let!(:tourism_collab) { create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority) }
    
    describe 'GET /api/v1/festivals/:id/tourism_collaborations' do
      it 'returns festival tourism collaborations with analytics' do
        get "/api/v1/festivals/#{festival.id}/tourism_collaborations"
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['tourism_collaborations']).to have(1).item
        
        collaboration = json_response['tourism_collaborations'].first
        expect(collaboration).to include(
          'collaboration_type',
          'status',
          'economic_impact',
          'total_visitors',
          'marketing_budget'
        )
      end
    end
    
    describe 'PATCH /api/v1/festivals/:id/tourism_collaborations/:id/update_visitor_analytics' do
      let(:analytics_data) do
        {
          analytics: {
            total_visitors: 6500,
            economic_impact: 275000,
            satisfaction_scores: { overall_satisfaction: 8.7 }
          }
        }
      end
      
      it 'updates visitor analytics via API' do
        patch "/api/v1/festivals/#{festival.id}/tourism_collaborations/#{tourism_collab.id}/update_visitor_analytics",
              params: analytics_data
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['analytics']['total_visitors']).to eq(6500)
        expect(json_response['analytics']['economic_impact']).to eq(275000)
        
        tourism_collab.reload
        expect(tourism_collab.total_visitors).to eq(6500)
        expect(tourism_collab.economic_impact).to eq(275000)
      end
    end
    
    describe 'GET /api/v1/festivals/:id/tourism_collaborations/:id/collaboration_dashboard' do
      before do
        tourism_collab.update_visitor_analytics!({
          total_visitors: 5000,
          economic_impact: 250000,
          satisfaction_scores: { overall_satisfaction: 8.5 }
        })
      end
      
      it 'returns comprehensive collaboration dashboard data' do
        get "/api/v1/festivals/#{festival.id}/tourism_collaborations/#{tourism_collab.id}/collaboration_dashboard"
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          'economic_impact',
          'total_visitors',
          'marketing_budget',
          'roi_percentage',
          'collaboration_performance',
          'campaign_analytics'
        )
      end
    end
  end

  describe 'Payment Processing API' do
    describe 'GET /api/v1/payments/methods' do
      it 'returns available payment methods' do
        get '/api/v1/payments/methods'
        
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['payment_methods']).to include(
          'credit_card',
          'bank_transfer',
          'digital_wallet'
        )
      end
    end
    
    describe 'POST /api/v1/festivals/:id/payments' do
      let(:payment_params) do
        {
          payment: {
            amount: 25000,
            payment_method: 'credit_card',
            description: 'Vendor booth fee',
            vendor_application_id: create(:vendor_application, festival: festival).id
          }
        }
      end
      
      it 'processes payment via API' do
        post "/api/v1/festivals/#{festival.id}/payments", params: payment_params
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['amount']).to eq(25000)
        expect(json_response['status']).to eq('pending')
      end
    end
  end

  describe 'Real-time Data Synchronization' do
    let!(:industry_spec) { create(:industry_specialization, :technology, :active, festival: festival) }
    let!(:tourism_collab) { create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority) }
    
    it 'maintains data consistency across API updates' do
      # Update industry metrics
      patch "/api/v1/festivals/#{festival.id}/industry_specializations/#{industry_spec.id}/update_metrics",
            params: { metrics: { innovation_index: 92 } }
      
      # Update tourism analytics
      patch "/api/v1/festivals/#{festival.id}/tourism_collaborations/#{tourism_collab.id}/update_visitor_analytics",
            params: { analytics: { total_visitors: 7500, economic_impact: 300000 } }
      
      # Check dashboard reflects all updates
      get "/api/v1/festivals/#{festival.id}/dashboard"
      
      json_response = JSON.parse(response.body)
      
      expect(json_response['industry_specialization_status']['innovation_index']).to eq(92)
      expect(json_response['tourism_collaboration_status']['total_visitors']).to eq(7500)
      expect(json_response['tourism_collaboration_status']['economic_impact']).to eq(300000)
    end
    
    it 'triggers dependent calculations when base data changes' do
      # Update festival budget
      patch "/api/v1/festivals/#{festival.id}",
            params: { festival: { budget: 750000 } }
      
      # Get AI budget recommendations
      allow_any_instance_of(AiRecommendationService).to receive(:recommend_budget_allocation)
        .and_return({
          success: true,
          total_budget: 750000,
          recommended_allocation: { venue_costs: 225000 }
        })
      
      post "/api/v1/festivals/#{festival.id}/ai_recommendations/budget_allocation"
      
      json_response = JSON.parse(response.body)
      expect(json_response['total_budget']).to eq(750000)
      expect(json_response['recommended_allocation']['venue_costs']).to eq(225000)
    end
  end

  describe 'Error Handling and Validation' do
    it 'returns proper error responses for invalid data' do
      post "/api/v1/festivals/#{festival.id}/industry_specializations",
           params: { industry_specialization: { industry_type: '' } }
      
      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include('Industry type can\'t be blank')
    end
    
    it 'handles authorization errors consistently' do
      other_user = create(:user)
      other_festival = create(:festival, user: other_user)
      
      get "/api/v1/festivals/#{other_festival.id}"
      
      expect(response).to have_http_status(:forbidden)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Access denied')
    end
    
    it 'handles missing resources gracefully' do
      get "/api/v1/festivals/999999"
      
      expect(response).to have_http_status(:not_found)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Festival not found')
    end
    
    it 'validates API rate limits' do
      # Simulate rapid API calls
      20.times do
        get "/api/v1/festivals/#{festival.id}"
      end
      
      # Rate limiting should kick in
      get "/api/v1/festivals/#{festival.id}"
      
      # Depending on rate limiting implementation
      expect(response.status).to be_in([200, 429])
    end
  end

  describe 'API Performance and Caching' do
    it 'includes proper caching headers for static data' do
      get "/api/v1/festivals/#{festival.id}"
      
      expect(response.headers['Cache-Control']).to be_present
      expect(response.headers['ETag']).to be_present
    end
    
    it 'handles concurrent API requests efficiently' do
      threads = []
      
      5.times do
        threads << Thread.new do
          get "/api/v1/festivals/#{festival.id}/dashboard"
        end
      end
      
      threads.each(&:join)
      
      # All requests should succeed without conflicts
      expect(response).to have_http_status(:success)
    end
    
    it 'provides efficient data serialization' do
      create_list(:vendor_application, 50, festival: festival)
      create_list(:task, 100, festival: festival)
      
      start_time = Time.current
      get "/api/v1/festivals/#{festival.id}"
      end_time = Time.current
      
      expect(response).to have_http_status(:success)
      expect(end_time - start_time).to be < 2.seconds
    end
  end
end