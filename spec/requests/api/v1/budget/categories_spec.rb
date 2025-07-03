require 'rails_helper'

RSpec.describe "Api::V1::Budget::Categories", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/budget/categories/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/api/v1/budget/categories/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/api/v1/budget/categories/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/api/v1/budget/categories/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/api/v1/budget/categories/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
