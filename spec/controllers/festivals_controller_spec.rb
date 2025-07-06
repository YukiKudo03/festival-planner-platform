require 'rails_helper'

RSpec.describe FestivalsController, type: :controller do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:festival) { create(:festival, user: user) }
  let(:other_festival) { create(:festival) }
  
  before do
    sign_in_for_test user
  end
  
  describe 'GET #index' do
    let!(:user_festival) { create(:festival, user: user) }
    let!(:public_festival) { create(:festival, public: true) }
    let!(:private_festival) { create(:festival, public: false) }
    
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end
    
    it 'assigns accessible festivals to @festivals' do
      get :index
      expect(assigns(:festivals)).to include(user_festival)
      expect(assigns(:festivals)).to include(public_festival)
      expect(assigns(:festivals)).not_to include(private_festival)
    end
    
    it 'includes pagination' do
      get :index
      expect(assigns(:festivals)).to respond_to(:current_page)
    end
    
    context 'with search parameter' do
      let!(:searchable_festival) { create(:festival, name: 'Summer Festival', public: true) }
      
      it 'filters festivals by search term' do
        get :index, params: { search: 'Summer' }
        expect(assigns(:festivals)).to include(searchable_festival)
      end
    end
    
    context 'with status filter' do
      let!(:active_festival) { create(:festival, status: :active, public: true) }
      let!(:planning_festival) { create(:festival, status: :planning, public: true) }
      
      it 'filters festivals by status' do
        get :index, params: { status: 'active' }
        expect(assigns(:festivals)).to include(active_festival)
        expect(assigns(:festivals)).not_to include(planning_festival)
      end
    end
  end
  
  describe 'GET #show' do
    context 'when festival is accessible' do
      it 'returns a successful response' do
        get :show, params: { id: festival.id }
        expect(response).to be_successful
      end
      
      it 'assigns the festival to @festival' do
        get :show, params: { id: festival.id }
        expect(assigns(:festival)).to eq(festival)
      end
    end
    
    context 'when festival is not accessible' do
      before { sign_in create(:user) }
      
      it 'redirects to festivals index' do
        get :show, params: { id: other_festival.id }
        expect(response).to redirect_to(festivals_path)
      end
      
      it 'sets a flash error message' do
        get :show, params: { id: other_festival.id }
        expect(flash[:alert]).to be_present
      end
    end
    
    context 'when festival does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: 'nonexistent' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
  
  describe 'GET #new' do
    context 'when user can create festivals' do
      it 'returns a successful response' do
        get :new
        expect(response).to be_successful
      end
      
      it 'assigns a new festival to @festival' do
        get :new
        expect(assigns(:festival)).to be_a_new(Festival)
      end
    end
    
    context 'when user cannot create festivals' do
      let(:restricted_user) { create(:user, role: :resident) }
      
      before { sign_in restricted_user }
      
      it 'redirects to festivals index' do
        get :new
        expect(response).to redirect_to(festivals_path)
      end
    end
  end
  
  describe 'POST #create' do
    let(:valid_attributes) do
      {
        name: 'Test Festival',
        description: 'A test festival',
        start_date: 1.month.from_now,
        end_date: 1.month.from_now + 2.days,
        location: 'Test City',
        budget: 100000,
        capacity: 1000
      }
    end
    
    let(:invalid_attributes) do
      {
        name: '',
        start_date: nil,
        end_date: nil
      }
    end
    
    context 'with valid parameters' do
      it 'creates a new festival' do
        expect {
          post :create, params: { festival: valid_attributes }
        }.to change(Festival, :count).by(1)
      end
      
      it 'assigns the festival to the current user' do
        post :create, params: { festival: valid_attributes }
        expect(assigns(:festival).user).to eq(user)
      end
      
      it 'redirects to the created festival' do
        post :create, params: { festival: valid_attributes }
        expect(response).to redirect_to(Festival.last)
      end
      
      it 'sets a success flash message' do
        post :create, params: { festival: valid_attributes }
        expect(flash[:notice]).to be_present
      end
    end
    
    context 'with invalid parameters' do
      it 'does not create a festival' do
        expect {
          post :create, params: { festival: invalid_attributes }
        }.not_to change(Festival, :count)
      end
      
      it 'renders the new template' do
        post :create, params: { festival: invalid_attributes }
        expect(response).to render_template(:new)
      end
      
      it 'returns unprocessable entity status' do
        post :create, params: { festival: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
  
  describe 'GET #edit' do
    context 'when user can edit the festival' do
      it 'returns a successful response' do
        get :edit, params: { id: festival.id }
        expect(response).to be_successful
      end
      
      it 'assigns the festival to @festival' do
        get :edit, params: { id: festival.id }
        expect(assigns(:festival)).to eq(festival)
      end
    end
    
    context 'when user cannot edit the festival' do
      before { sign_in create(:user) }
      
      it 'redirects to festivals index' do
        get :edit, params: { id: other_festival.id }
        expect(response).to redirect_to(festivals_path)
      end
    end
  end
  
  describe 'PATCH #update' do
    let(:new_attributes) do
      {
        name: 'Updated Festival Name',
        description: 'Updated description'
      }
    end
    
    context 'with valid parameters' do
      it 'updates the festival' do
        patch :update, params: { id: festival.id, festival: new_attributes }
        festival.reload
        expect(festival.name).to eq('Updated Festival Name')
      end
      
      it 'redirects to the festival' do
        patch :update, params: { id: festival.id, festival: new_attributes }
        expect(response).to redirect_to(festival)
      end
      
      it 'sets a success flash message' do
        patch :update, params: { id: festival.id, festival: new_attributes }
        expect(flash[:notice]).to be_present
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_attributes) { { name: '' } }
      
      it 'does not update the festival' do
        original_name = festival.name
        patch :update, params: { id: festival.id, festival: invalid_attributes }
        festival.reload
        expect(festival.name).to eq(original_name)
      end
      
      it 'renders the edit template' do
        patch :update, params: { id: festival.id, festival: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
    
    context 'when user cannot edit the festival' do
      before { sign_in create(:user) }
      
      it 'redirects to festivals index' do
        patch :update, params: { id: other_festival.id, festival: new_attributes }
        expect(response).to redirect_to(festivals_path)
      end
    end
  end
  
  describe 'DELETE #destroy' do
    let!(:festival_to_delete) { create(:festival, user: user) }
    
    context 'when user can delete the festival' do
      it 'destroys the festival' do
        expect {
          delete :destroy, params: { id: festival_to_delete.id }
        }.to change(Festival, :count).by(-1)
      end
      
      it 'redirects to festivals index' do
        delete :destroy, params: { id: festival_to_delete.id }
        expect(response).to redirect_to(festivals_path)
      end
      
      it 'sets a success flash message' do
        delete :destroy, params: { id: festival_to_delete.id }
        expect(flash[:notice]).to be_present
      end
    end
    
    context 'when user cannot delete the festival' do
      before { sign_in create(:user) }
      
      it 'does not destroy the festival' do
        expect {
          delete :destroy, params: { id: other_festival.id }
        }.not_to change(Festival, :count)
      end
      
      it 'redirects to festivals index' do
        delete :destroy, params: { id: other_festival.id }
        expect(response).to redirect_to(festivals_path)
      end
    end
  end
  
  describe 'POST #join' do
    let(:public_festival) { create(:festival, public: true) }
    let(:private_festival) { create(:festival, public: false) }
    
    context 'when festival is public' do
      it 'allows user to join' do
        post :join, params: { id: public_festival.id }
        expect(response).to redirect_to(public_festival)
      end
      
      it 'sets a success flash message' do
        post :join, params: { id: public_festival.id }
        expect(flash[:notice]).to be_present
      end
    end
    
    context 'when festival is private' do
      it 'redirects with error message' do
        post :join, params: { id: private_festival.id }
        expect(response).to redirect_to(festivals_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
  
  describe 'authentication and authorization' do
    context 'when user is not signed in' do
      before { sign_out user }
      
      it 'redirects to sign in page for protected actions' do
        get :new
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context 'when user is admin' do
      before { sign_in admin }
      
      it 'allows access to any festival' do
        get :show, params: { id: other_festival.id }
        expect(response).to be_successful
      end
      
      it 'allows editing any festival' do
        get :edit, params: { id: other_festival.id }
        expect(response).to be_successful
      end
    end
  end
  
  describe 'format handling' do
    context 'when requesting JSON format' do
      it 'returns JSON response for index' do
        get :index, format: :json
        expect(response.content_type).to include('application/json')
      end
      
      it 'returns JSON response for show' do
        get :show, params: { id: festival.id }, format: :json
        expect(response.content_type).to include('application/json')
      end
    end
  end
  
  describe 'error handling' do
    context 'when ActiveRecord::RecordNotFound is raised' do
      it 'handles the exception gracefully' do
        expect {
          get :show, params: { id: 'nonexistent' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end