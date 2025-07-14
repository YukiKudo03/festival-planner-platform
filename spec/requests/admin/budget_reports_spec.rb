require 'rails_helper'

RSpec.describe "Admin::BudgetReports", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/admin/budget_reports/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/admin/budget_reports/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /dashboard" do
    it "returns http success" do
      get "/admin/budget_reports/dashboard"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /analytics" do
    it "returns http success" do
      get "/admin/budget_reports/analytics"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /export" do
    it "returns http success" do
      get "/admin/budget_reports/export"
      expect(response).to have_http_status(:success)
    end
  end
end
