require 'rails_helper'

RSpec.describe "Api::V1::Festivals", type: :request do
  let(:user) { create(:user, role: :admin) }
  let(:api_token) { user.tap(&:generate_api_token!).api_token }
  let(:headers) { { 'Authorization' => "Bearer #{api_token}", 'Content-Type' => 'application/json' } }
  let(:festival) { create(:festival, user: user) }

  describe "GET /api/v1/festivals" do
    before do
      create_list(:festival, 3, user: user)
      create(:festival, public: true) # Public festival
    end

    context "with valid authentication" do
      it "returns list of accessible festivals" do
        get "/api/v1/festivals", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']).to be_an(Array)
        expect(json['meta']).to include('current_page', 'total_pages', 'total_count')
      end

      it "filters festivals by status" do
        active_festival = create(:festival, status: :active, user: user)
        
        get "/api/v1/festivals", 
            params: { filters: { status: 'active' }.to_json }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].length).to eq(1)
        expect(json['data'][0]['id']).to eq(active_festival.id)
      end

      it "supports pagination" do
        get "/api/v1/festivals", 
            params: { page: 1, per_page: 2 }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].length).to eq(2)
        expect(json['meta']['per_page']).to eq(2)
        expect(json['meta']['current_page']).to eq(1)
      end
    end

    context "without authentication" do
      it "returns unauthorized error" do
        get "/api/v1/festivals"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to include('認証トークン')
      end
    end

    context "with invalid token" do
      it "returns unauthorized error" do
        invalid_headers = { 'Authorization' => "Bearer invalid_token" }
        get "/api/v1/festivals", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end

  describe "GET /api/v1/festivals/:id" do
    context "with valid authentication and access" do
      it "returns festival details" do
        get "/api/v1/festivals/#{festival.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']['id']).to eq(festival.id)
        expect(json['data']['name']).to eq(festival.name)
        expect(json['data']).to include('budget', 'completion_rate', 'vendor_count')
      end
    end

    context "without access permission" do
      let(:other_user) { create(:user) }
      let(:private_festival) { create(:festival, user: other_user, public: false) }

      it "returns forbidden error" do
        get "/api/v1/festivals/#{private_festival.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end

    context "with non-existent festival" do
      it "returns not found error" do
        get "/api/v1/festivals/99999", headers: headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end

  describe "POST /api/v1/festivals" do
    let(:valid_attributes) do
      {
        festival: {
          name: "Test Festival",
          description: "A test festival",
          start_date: 1.month.from_now,
          end_date: 1.month.from_now + 3.days,
          location: "Test City",
          budget: 100000,
          capacity: 1000,
          public: true
        }
      }
    end

    context "with valid attributes" do
      it "creates a new festival" do
        expect {
          post "/api/v1/festivals", 
               params: valid_attributes.to_json, 
               headers: headers
        }.to change(Festival, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']['name']).to eq("Test Festival")
        expect(json['message']).to include('作成しました')
      end

      it "creates default budget categories" do
        post "/api/v1/festivals", 
             params: valid_attributes.to_json, 
             headers: headers

        festival = Festival.last
        expect(festival.budget_categories.count).to be > 0
      end
    end

    context "with invalid attributes" do
      it "returns validation errors" do
        invalid_attributes = valid_attributes.deep_dup
        invalid_attributes[:festival][:name] = ""

        post "/api/v1/festivals", 
             params: invalid_attributes.to_json, 
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be false
        expect(json['errors']).to be_present
      end
    end

    context "without permission" do
      let(:regular_user) { create(:user, role: :resident) }
      let(:regular_headers) do
        token = regular_user.tap(&:generate_api_token!).api_token
        { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
      end

      it "returns forbidden error" do
        post "/api/v1/festivals", 
             params: valid_attributes.to_json, 
             headers: regular_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end

  describe "PATCH /api/v1/festivals/:id" do
    let(:update_attributes) do
      {
        festival: {
          name: "Updated Festival Name",
          description: "Updated description"
        }
      }
    end

    context "with valid updates" do
      it "updates the festival" do
        patch "/api/v1/festivals/#{festival.id}", 
              params: update_attributes.to_json, 
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']['name']).to eq("Updated Festival Name")
        
        festival.reload
        expect(festival.name).to eq("Updated Festival Name")
      end
    end

    context "without permission" do
      let(:other_user) { create(:user) }
      let(:other_festival) { create(:festival, user: other_user) }

      it "returns forbidden error" do
        patch "/api/v1/festivals/#{other_festival.id}", 
              params: update_attributes.to_json, 
              headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/festivals/:id" do
    context "with permission" do
      it "deletes the festival" do
        festival_id = festival.id
        
        expect {
          delete "/api/v1/festivals/#{festival_id}", headers: headers
        }.to change(Festival, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end

    context "without permission" do
      let(:other_user) { create(:user) }
      let(:other_festival) { create(:festival, user: other_user) }

      it "returns forbidden error" do
        delete "/api/v1/festivals/#{other_festival.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/festivals/:id/analytics" do
    before do
      # Create test data for analytics
      create(:task, festival: festival, status: :completed)
      create(:vendor_application, festival: festival, status: :approved)
      create(:payment, festival: festival, user: user, status: :completed, amount: 5000)
    end

    it "returns comprehensive analytics data" do
      get "/api/v1/festivals/#{festival.id}/analytics", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['success']).to be true
      expect(json['data']).to include(
        'overview', 'budget', 'tasks', 'vendors', 
        'venue', 'communication', 'trends', 'recommendations'
      )
    end

    it "accepts date range parameters" do
      get "/api/v1/festivals/#{festival.id}/analytics", 
          params: { 
            start_date: 1.month.ago.to_date, 
            end_date: Date.current 
          }, 
          headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/festivals/:id/dashboard" do
    it "returns dashboard data" do
      get "/api/v1/festivals/#{festival.id}/dashboard", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['success']).to be true
      expect(json['data']).to include('overview', 'budget_analytics', 'task_analytics')
    end
  end

  describe "POST /api/v1/festivals/:id/join" do
    let(:member_user) { create(:user) }
    let(:member_headers) do
      token = member_user.tap(&:generate_api_token!).api_token
      { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
    end

    context "with public festival" do
      before { festival.update!(public: true) }

      it "allows user to join festival" do
        post "/api/v1/festivals/#{festival.id}/join", headers: member_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end

    context "with private festival" do
      before { festival.update!(public: false) }

      it "denies access to private festival" do
        post "/api/v1/festivals/#{festival.id}/join", headers: member_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "Rate limiting" do
    it "enforces rate limits for API requests" do
      # Make requests up to the limit
      101.times do
        get "/api/v1/festivals", headers: headers
      end

      expect(response).to have_http_status(:too_many_requests)
      json = JSON.parse(response.body)
      expect(json['message']).to include('レート制限')
    end
  end

  describe "API versioning" do
    it "accepts API version header" do
      versioned_headers = headers.merge('API-Version' => 'v1')
      
      get "/api/v1/festivals", headers: versioned_headers
      
      expect(response).to have_http_status(:ok)
    end
  end
end