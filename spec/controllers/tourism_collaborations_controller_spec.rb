# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TourismCollaborationsController, type: :controller do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:municipal_authority) { create(:municipal_authority) }
  let(:tourism_collaboration) { create(:tourism_collaboration, festival: festival, municipal_authority: municipal_authority) }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:collaborations) { create_list(:tourism_collaboration, 3, festival: festival) }
    
    it 'returns a success response' do
      get :index, params: { festival_id: festival.id }
      expect(response).to be_successful
    end
    
    it 'assigns festival tourism collaborations' do
      get :index, params: { festival_id: festival.id }
      expect(assigns(:tourism_collaborations)).to match_array(collaborations)
    end
    
    it 'responds to JSON format' do
      get :index, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
    
    it 'includes municipal authority information' do
      get :index, params: { festival_id: festival.id }
      expect(assigns(:tourism_collaborations).first.municipal_authority).to be_present
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response).to be_successful
    end
    
    it 'assigns the requested tourism collaboration' do
      get :show, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(assigns(:tourism_collaboration)).to eq(tourism_collaboration)
    end
    
    it 'responds to JSON format' do
      get :show, params: { festival_id: festival.id, id: tourism_collaboration.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(tourism_collaboration.id)
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new, params: { festival_id: festival.id }
      expect(response).to be_successful
    end
    
    it 'assigns a new tourism collaboration' do
      get :new, params: { festival_id: festival.id }
      expect(assigns(:tourism_collaboration)).to be_a_new(TourismCollaboration)
      expect(assigns(:tourism_collaboration).festival).to eq(festival)
    end
    
    it 'loads available municipal authorities' do
      create_list(:municipal_authority, 3, :active)
      get :new, params: { festival_id: festival.id }
      expect(assigns(:municipal_authorities)).to be_present
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      get :edit, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response).to be_successful
    end
    
    it 'assigns the requested tourism collaboration' do
      get :edit, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(assigns(:tourism_collaboration)).to eq(tourism_collaboration)
    end
    
    it 'loads available municipal authorities' do
      get :edit, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(assigns(:municipal_authorities)).to be_present
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) do
        {
          municipal_authority_id: municipal_authority.id,
          collaboration_type: 'tourism_board',
          partnership_details: {
            budget_contribution: 25000,
            resource_sharing: ['marketing_channels', 'visitor_data']
          }.to_json,
          marketing_campaigns: {
            social_media: { budget: 10000, platforms: ['facebook', 'instagram'] }
          }.to_json,
          visitor_analytics: {
            total_visitors: 0,
            demographics: {}
          }.to_json
        }
      end
      
      it 'creates a new TourismCollaboration' do
        expect {
          post :create, params: { festival_id: festival.id, tourism_collaboration: valid_attributes }
        }.to change(TourismCollaboration, :count).by(1)
      end
      
      it 'redirects to the created tourism collaboration' do
        post :create, params: { festival_id: festival.id, tourism_collaboration: valid_attributes }
        expect(response).to redirect_to([festival, TourismCollaboration.last])
      end
      
      it 'sets the festival association' do
        post :create, params: { festival_id: festival.id, tourism_collaboration: valid_attributes }
        expect(TourismCollaboration.last.festival).to eq(festival)
      end
      
      it 'responds to JSON format' do
        post :create, params: { festival_id: festival.id, tourism_collaboration: valid_attributes }, format: :json
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['collaboration_type']).to eq('tourism_board')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        {
          municipal_authority_id: nil,
          collaboration_type: '',
          partnership_details: 'invalid json',
          marketing_campaigns: '',
          visitor_analytics: ''
        }
      end
      
      it 'does not create a new TourismCollaboration' do
        expect {
          post :create, params: { festival_id: festival.id, tourism_collaboration: invalid_attributes }
        }.not_to change(TourismCollaboration, :count)
      end
      
      it 'renders the new template' do
        post :create, params: { festival_id: festival.id, tourism_collaboration: invalid_attributes }
        expect(response).to render_template(:new)
      end
      
      it 'responds with unprocessable entity for JSON' do
        post :create, params: { festival_id: festival.id, tourism_collaboration: invalid_attributes }, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        {
          collaboration_type: 'marketing_partnership',
          partnership_details: {
            budget_contribution: 15000,
            resource_sharing: ['advertising_space', 'social_media_promotion']
          }.to_json
        }
      end
      
      it 'updates the requested tourism collaboration' do
        patch :update, params: { festival_id: festival.id, id: tourism_collaboration.id, tourism_collaboration: new_attributes }
        tourism_collaboration.reload
        expect(tourism_collaboration.collaboration_type).to eq('marketing_partnership')
      end
      
      it 'redirects to the tourism collaboration' do
        patch :update, params: { festival_id: festival.id, id: tourism_collaboration.id, tourism_collaboration: new_attributes }
        expect(response).to redirect_to([festival, tourism_collaboration])
      end
      
      it 'responds to JSON format' do
        patch :update, params: { festival_id: festival.id, id: tourism_collaboration.id, tourism_collaboration: new_attributes }, format: :json
        expect(response).to be_successful
        
        json_response = JSON.parse(response.body)
        expect(json_response['collaboration_type']).to eq('marketing_partnership')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { collaboration_type: '', partnership_details: 'invalid json' }
      end
      
      it 'does not update the tourism collaboration' do
        original_type = tourism_collaboration.collaboration_type
        patch :update, params: { festival_id: festival.id, id: tourism_collaboration.id, tourism_collaboration: invalid_attributes }
        tourism_collaboration.reload
        expect(tourism_collaboration.collaboration_type).to eq(original_type)
      end
      
      it 'renders the edit template' do
        patch :update, params: { festival_id: festival.id, id: tourism_collaboration.id, tourism_collaboration: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested tourism collaboration' do
      tourism_collaboration # create the record
      expect {
        delete :destroy, params: { festival_id: festival.id, id: tourism_collaboration.id }
      }.to change(TourismCollaboration, :count).by(-1)
    end
    
    it 'redirects to the tourism collaborations list' do
      delete :destroy, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response).to redirect_to(festival_tourism_collaborations_url(festival))
    end
    
    it 'responds to JSON format' do
      delete :destroy, params: { festival_id: festival.id, id: tourism_collaboration.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'PATCH #approve' do
    before do
      tourism_collaboration.update!(status: 'proposed')
    end
    
    it 'approves the tourism collaboration' do
      patch :approve, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.status).to eq('approved')
    end
    
    it 'sets approved_at timestamp' do
      patch :approve, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.approved_at).to be_present
    end
    
    it 'redirects to the tourism collaboration' do
      patch :approve, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response).to redirect_to([festival, tourism_collaboration])
    end
    
    it 'responds to JSON format' do
      patch :approve, params: { festival_id: festival.id, id: tourism_collaboration.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('approved')
    end
  end

  describe 'PATCH #activate' do
    before do
      tourism_collaboration.update!(status: 'approved')
    end
    
    it 'activates the tourism collaboration' do
      patch :activate, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.status).to eq('active')
    end
    
    it 'sets activated_at timestamp' do
      patch :activate, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.activated_at).to be_present
    end
  end

  describe 'PATCH #complete' do
    before do
      tourism_collaboration.update!(status: 'active')
    end
    
    it 'completes the tourism collaboration' do
      patch :complete, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.status).to eq('completed')
    end
    
    it 'sets completed_at timestamp' do
      patch :complete, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.completed_at).to be_present
    end
  end

  describe 'PATCH #cancel' do
    it 'cancels the tourism collaboration' do
      patch :cancel, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.status).to eq('cancelled')
    end
    
    it 'sets cancelled_at timestamp' do
      patch :cancel, params: { festival_id: festival.id, id: tourism_collaboration.id }
      tourism_collaboration.reload
      expect(tourism_collaboration.cancelled_at).to be_present
    end
  end

  describe 'PATCH #update_visitor_analytics' do
    let(:new_analytics) do
      {
        total_visitors: 5000,
        economic_impact: 250000,
        satisfaction_scores: { overall_satisfaction: 8.5 }
      }
    end
    
    it 'updates the visitor analytics' do
      patch :update_visitor_analytics, params: { festival_id: festival.id, id: tourism_collaboration.id, analytics: new_analytics }
      tourism_collaboration.reload
      
      analytics = tourism_collaboration.analytics
      expect(analytics['total_visitors']).to eq(5000)
      expect(analytics['economic_impact']).to eq(250000)
    end
    
    it 'responds to JSON format' do
      patch :update_visitor_analytics, params: { festival_id: festival.id, id: tourism_collaboration.id, analytics: new_analytics }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['analytics']['total_visitors']).to eq(5000)
    end
    
    it 'merges with existing analytics' do
      existing_analytics = { demographics: { local: 40, regional: 35 } }
      tourism_collaboration.update!(visitor_analytics: existing_analytics.to_json)
      
      patch :update_visitor_analytics, params: { festival_id: festival.id, id: tourism_collaboration.id, analytics: new_analytics }
      tourism_collaboration.reload
      
      analytics = tourism_collaboration.analytics
      expect(analytics['demographics']['local']).to eq(40)
      expect(analytics['total_visitors']).to eq(5000)
    end
  end

  describe 'GET #collaboration_dashboard' do
    before do
      tourism_collaboration.update!(status: 'active')
    end
    
    it 'returns a success response' do
      get :collaboration_dashboard, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response).to be_successful
    end
    
    it 'assigns dashboard data' do
      get :collaboration_dashboard, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(assigns(:dashboard_data)).to be_present
      expect(assigns(:dashboard_data)).to include(:economic_impact, :total_visitors, :marketing_budget)
    end
    
    it 'responds to JSON format' do
      get :collaboration_dashboard, params: { festival_id: festival.id, id: tourism_collaboration.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response).to include('economic_impact', 'total_visitors', 'marketing_budget')
    end
  end

  describe 'GET #export_report' do
    before do
      tourism_collaboration.update!(status: 'completed', visitor_analytics: { total_visitors: 5000, economic_impact: 200000 }.to_json)
    end
    
    it 'returns a success response' do
      get :export_report, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response).to be_successful
    end
    
    it 'sets proper headers for file download' do
      get :export_report, params: { festival_id: festival.id, id: tourism_collaboration.id }
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
    end
    
    it 'responds to JSON format with report data' do
      get :export_report, params: { festival_id: festival.id, id: tourism_collaboration.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response).to include('collaboration_summary', 'performance_metrics')
    end
  end

  describe 'authorization' do
    context 'when user does not own the festival' do
      let(:other_user) { create(:user) }
      let(:other_festival) { create(:festival, user: other_user) }
      let(:other_collaboration) { create(:tourism_collaboration, festival: other_festival) }
      
      it 'denies access to index' do
        get :index, params: { festival_id: other_festival.id }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to show' do
        get :show, params: { festival_id: other_festival.id, id: other_collaboration.id }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to create' do
        post :create, params: { festival_id: other_festival.id, tourism_collaboration: { collaboration_type: 'tourism_board' } }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to update' do
        patch :update, params: { festival_id: other_festival.id, id: other_collaboration.id, tourism_collaboration: { collaboration_type: 'marketing_partnership' } }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to destroy' do
        delete :destroy, params: { festival_id: other_festival.id, id: other_collaboration.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'error handling' do
    it 'handles record not found gracefully' do
      get :show, params: { festival_id: festival.id, id: 'nonexistent' }
      expect(response).to redirect_to(festival_tourism_collaborations_path(festival))
      expect(flash[:alert]).to be_present
    end
    
    it 'handles invalid festival ID' do
      get :index, params: { festival_id: 'nonexistent' }
      expect(response).to redirect_to(festivals_path)
      expect(flash[:alert]).to be_present
    end
    
    it 'handles invalid municipal authority assignment' do
      invalid_attributes = { municipal_authority_id: 999999, collaboration_type: 'tourism_board' }
      post :create, params: { festival_id: festival.id, tourism_collaboration: invalid_attributes }
      expect(response).to render_template(:new)
    end
  end

  describe 'filtering and searching' do
    let!(:tourism_board_collab) { create(:tourism_collaboration, :tourism_board, festival: festival) }
    let!(:marketing_collab) { create(:tourism_collaboration, :marketing_partnership, festival: festival) }
    let!(:active_collab) { create(:tourism_collaboration, :active, festival: festival) }
    
    it 'filters by collaboration type' do
      get :index, params: { festival_id: festival.id, collaboration_type: 'tourism_board' }
      expect(assigns(:tourism_collaborations)).to contain_exactly(tourism_board_collab)
    end
    
    it 'filters by status' do
      get :index, params: { festival_id: festival.id, status: 'active' }
      expect(assigns(:tourism_collaborations)).to contain_exactly(active_collab)
    end
    
    it 'filters by municipal authority' do
      authority = tourism_board_collab.municipal_authority
      get :index, params: { festival_id: festival.id, municipal_authority_id: authority.id }
      expect(assigns(:tourism_collaborations)).to contain_exactly(tourism_board_collab)
    end
  end

  describe 'analytics and reporting' do
    it 'calculates total economic impact' do
      create(:tourism_collaboration, :completed, festival: festival, visitor_analytics: { economic_impact: 100000 }.to_json)
      create(:tourism_collaboration, :completed, festival: festival, visitor_analytics: { economic_impact: 150000 }.to_json)
      
      get :index, params: { festival_id: festival.id }
      expect(assigns(:total_economic_impact)).to eq(250000)
    end
    
    it 'calculates total visitor count' do
      create(:tourism_collaboration, :completed, festival: festival, visitor_analytics: { total_visitors: 3000 }.to_json)
      create(:tourism_collaboration, :completed, festival: festival, visitor_analytics: { total_visitors: 2000 }.to_json)
      
      get :index, params: { festival_id: festival.id }
      expect(assigns(:total_visitors)).to eq(5000)
    end
  end

  describe 'performance and caching' do
    it 'includes proper associations to avoid N+1 queries' do
      create_list(:tourism_collaboration, 5, festival: festival)
      
      expect { 
        get :index, params: { festival_id: festival.id }
      }.not_to exceed_query_limit(5) # Adjust based on actual query optimization
    end
  end
end