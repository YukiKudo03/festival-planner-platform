# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IndustrySpecializationsController, type: :controller do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:industry_specialization) { create(:industry_specialization, festival: festival) }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:specializations) { create_list(:industry_specialization, 3, festival: festival) }
    
    it 'returns a success response' do
      get :index, params: { festival_id: festival.id }
      expect(response).to be_successful
    end
    
    it 'assigns festival specializations' do
      get :index, params: { festival_id: festival.id }
      expect(assigns(:industry_specializations)).to match_array(specializations)
    end
    
    it 'responds to JSON format' do
      get :index, params: { festival_id: festival.id }, format: :json
      expect(response).to be_successful
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(response).to be_successful
    end
    
    it 'assigns the requested industry specialization' do
      get :show, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(assigns(:industry_specialization)).to eq(industry_specialization)
    end
    
    it 'responds to JSON format' do
      get :show, params: { festival_id: festival.id, id: industry_specialization.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['id']).to eq(industry_specialization.id)
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new, params: { festival_id: festival.id }
      expect(response).to be_successful
    end
    
    it 'assigns a new industry specialization' do
      get :new, params: { festival_id: festival.id }
      expect(assigns(:industry_specialization)).to be_a_new(IndustrySpecialization)
      expect(assigns(:industry_specialization).festival).to eq(festival)
    end
  end

  describe 'GET #edit' do
    it 'returns a success response' do
      get :edit, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(response).to be_successful
    end
    
    it 'assigns the requested industry specialization' do
      get :edit, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(assigns(:industry_specialization)).to eq(industry_specialization)
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) do
        {
          industry_type: 'technology',
          specialization_config: {
            booth_layout: 'tech_standard',
            equipment_requirements: ['wifi', 'power']
          }.to_json,
          compliance_requirements: {
            safety_standards: ['ISO 9001'],
            certifications: ['tech_certification']
          }.to_json,
          specialized_metrics: {
            kpis: ['innovation_index'],
            targets: { innovation_index: 85 }
          }.to_json
        }
      end
      
      it 'creates a new IndustrySpecialization' do
        expect {
          post :create, params: { festival_id: festival.id, industry_specialization: valid_attributes }
        }.to change(IndustrySpecialization, :count).by(1)
      end
      
      it 'redirects to the created industry specialization' do
        post :create, params: { festival_id: festival.id, industry_specialization: valid_attributes }
        expect(response).to redirect_to([festival, IndustrySpecialization.last])
      end
      
      it 'sets the festival association' do
        post :create, params: { festival_id: festival.id, industry_specialization: valid_attributes }
        expect(IndustrySpecialization.last.festival).to eq(festival)
      end
      
      it 'responds to JSON format' do
        post :create, params: { festival_id: festival.id, industry_specialization: valid_attributes }, format: :json
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['industry_type']).to eq('technology')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        {
          industry_type: '',
          specialization_config: 'invalid json',
          compliance_requirements: '',
          specialized_metrics: ''
        }
      end
      
      it 'does not create a new IndustrySpecialization' do
        expect {
          post :create, params: { festival_id: festival.id, industry_specialization: invalid_attributes }
        }.not_to change(IndustrySpecialization, :count)
      end
      
      it 'renders the new template' do
        post :create, params: { festival_id: festival.id, industry_specialization: invalid_attributes }
        expect(response).to render_template(:new)
      end
      
      it 'responds with unprocessable entity for JSON' do
        post :create, params: { festival_id: festival.id, industry_specialization: invalid_attributes }, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        {
          industry_type: 'healthcare',
          specialization_config: {
            booth_layout: 'healthcare_pavilion',
            equipment_requirements: ['medical_grade_power']
          }.to_json
        }
      end
      
      it 'updates the requested industry specialization' do
        patch :update, params: { festival_id: festival.id, id: industry_specialization.id, industry_specialization: new_attributes }
        industry_specialization.reload
        expect(industry_specialization.industry_type).to eq('healthcare')
      end
      
      it 'redirects to the industry specialization' do
        patch :update, params: { festival_id: festival.id, id: industry_specialization.id, industry_specialization: new_attributes }
        expect(response).to redirect_to([festival, industry_specialization])
      end
      
      it 'responds to JSON format' do
        patch :update, params: { festival_id: festival.id, id: industry_specialization.id, industry_specialization: new_attributes }, format: :json
        expect(response).to be_successful
        
        json_response = JSON.parse(response.body)
        expect(json_response['industry_type']).to eq('healthcare')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        { industry_type: '', specialization_config: 'invalid json' }
      end
      
      it 'does not update the industry specialization' do
        original_type = industry_specialization.industry_type
        patch :update, params: { festival_id: festival.id, id: industry_specialization.id, industry_specialization: invalid_attributes }
        industry_specialization.reload
        expect(industry_specialization.industry_type).to eq(original_type)
      end
      
      it 'renders the edit template' do
        patch :update, params: { festival_id: festival.id, id: industry_specialization.id, industry_specialization: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested industry specialization' do
      industry_specialization # create the record
      expect {
        delete :destroy, params: { festival_id: festival.id, id: industry_specialization.id }
      }.to change(IndustrySpecialization, :count).by(-1)
    end
    
    it 'redirects to the industry specializations list' do
      delete :destroy, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(response).to redirect_to(festival_industry_specializations_url(festival))
    end
    
    it 'responds to JSON format' do
      delete :destroy, params: { festival_id: festival.id, id: industry_specialization.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'PATCH #activate' do
    it 'activates the industry specialization' do
      patch :activate, params: { festival_id: festival.id, id: industry_specialization.id }
      industry_specialization.reload
      expect(industry_specialization.status).to eq('active')
    end
    
    it 'sets activated_at timestamp' do
      patch :activate, params: { festival_id: festival.id, id: industry_specialization.id }
      industry_specialization.reload
      expect(industry_specialization.activated_at).to be_present
    end
    
    it 'redirects to the industry specialization' do
      patch :activate, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(response).to redirect_to([festival, industry_specialization])
    end
    
    it 'responds to JSON format' do
      patch :activate, params: { festival_id: festival.id, id: industry_specialization.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('active')
    end
  end

  describe 'PATCH #complete' do
    before do
      industry_specialization.update!(status: 'active')
    end
    
    it 'completes the industry specialization' do
      patch :complete, params: { festival_id: festival.id, id: industry_specialization.id }
      industry_specialization.reload
      expect(industry_specialization.status).to eq('completed')
    end
    
    it 'sets completed_at timestamp' do
      patch :complete, params: { festival_id: festival.id, id: industry_specialization.id }
      industry_specialization.reload
      expect(industry_specialization.completed_at).to be_present
    end
    
    it 'redirects to the industry specialization' do
      patch :complete, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(response).to redirect_to([festival, industry_specialization])
    end
  end

  describe 'PATCH #update_metrics' do
    let(:new_metrics) do
      {
        leads_generated: 45,
        conversion_rate: 12.5,
        completed_tasks: 8
      }
    end
    
    it 'updates the specialized metrics' do
      patch :update_metrics, params: { festival_id: festival.id, id: industry_specialization.id, metrics: new_metrics }
      industry_specialization.reload
      
      metrics = industry_specialization.metrics
      expect(metrics['leads_generated']).to eq(45)
      expect(metrics['conversion_rate']).to eq(12.5)
    end
    
    it 'responds to JSON format' do
      patch :update_metrics, params: { festival_id: festival.id, id: industry_specialization.id, metrics: new_metrics }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['metrics']['leads_generated']).to eq(45)
    end
    
    it 'merges with existing metrics' do
      existing_metrics = { total_leads: 100 }
      industry_specialization.update!(specialized_metrics: existing_metrics.to_json)
      
      patch :update_metrics, params: { festival_id: festival.id, id: industry_specialization.id, metrics: new_metrics }
      industry_specialization.reload
      
      metrics = industry_specialization.metrics
      expect(metrics['total_leads']).to eq(100)
      expect(metrics['leads_generated']).to eq(45)
    end
  end

  describe 'GET #industry_dashboard' do
    before do
      industry_specialization.update!(status: 'active')
    end
    
    it 'returns a success response' do
      get :industry_dashboard, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(response).to be_successful
    end
    
    it 'assigns dashboard data' do
      get :industry_dashboard, params: { festival_id: festival.id, id: industry_specialization.id }
      expect(assigns(:dashboard_data)).to be_present
      expect(assigns(:dashboard_data)).to include(:progress_percentage, :compliance_score)
    end
    
    it 'responds to JSON format' do
      get :industry_dashboard, params: { festival_id: festival.id, id: industry_specialization.id }, format: :json
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response).to include('progress_percentage', 'compliance_score')
    end
  end

  describe 'authorization' do
    context 'when user does not own the festival' do
      let(:other_user) { create(:user) }
      let(:other_festival) { create(:festival, user: other_user) }
      let(:other_specialization) { create(:industry_specialization, festival: other_festival) }
      
      it 'denies access to index' do
        get :index, params: { festival_id: other_festival.id }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to show' do
        get :show, params: { festival_id: other_festival.id, id: other_specialization.id }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to create' do
        post :create, params: { festival_id: other_festival.id, industry_specialization: { industry_type: 'technology' } }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to update' do
        patch :update, params: { festival_id: other_festival.id, id: other_specialization.id, industry_specialization: { industry_type: 'healthcare' } }
        expect(response).to redirect_to(root_path)
      end
      
      it 'denies access to destroy' do
        delete :destroy, params: { festival_id: other_festival.id, id: other_specialization.id }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'error handling' do
    it 'handles record not found gracefully' do
      get :show, params: { festival_id: festival.id, id: 'nonexistent' }
      expect(response).to redirect_to(festival_industry_specializations_path(festival))
      expect(flash[:alert]).to be_present
    end
    
    it 'handles invalid festival ID' do
      get :index, params: { festival_id: 'nonexistent' }
      expect(response).to redirect_to(festivals_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'filtering and searching' do
    let!(:tech_specialization) { create(:industry_specialization, :technology, festival: festival) }
    let!(:healthcare_specialization) { create(:industry_specialization, :healthcare, festival: festival) }
    
    it 'filters by industry type' do
      get :index, params: { festival_id: festival.id, industry_type: 'technology' }
      expect(assigns(:industry_specializations)).to contain_exactly(tech_specialization)
    end
    
    it 'filters by status' do
      tech_specialization.update!(status: 'active')
      get :index, params: { festival_id: festival.id, status: 'active' }
      expect(assigns(:industry_specializations)).to contain_exactly(tech_specialization)
    end
  end

  describe 'performance and caching' do
    it 'includes proper associations to avoid N+1 queries' do
      create_list(:industry_specialization, 5, festival: festival)
      
      expect { 
        get :index, params: { festival_id: festival.id }
      }.not_to exceed_query_limit(5) # Adjust based on actual query optimization
    end
  end
end