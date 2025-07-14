require 'rails_helper'

RSpec.describe "Admin::Revenues", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/admin/revenues/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/admin/revenues/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/admin/revenues/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/admin/revenues/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/admin/revenues/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/admin/revenues/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/admin/revenues/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /confirm" do
    it "returns http success" do
      get "/admin/revenues/confirm"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /mark_received" do
    it "returns http success" do
      get "/admin/revenues/mark_received"
      expect(response).to have_http_status(:success)
    end
  end
end
