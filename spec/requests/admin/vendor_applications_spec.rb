require 'rails_helper'

RSpec.describe "Admin::VendorApplications", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/admin/vendor_applications/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/admin/vendor_applications/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /review" do
    it "returns http success" do
      get "/admin/vendor_applications/review"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /approve" do
    it "returns http success" do
      get "/admin/vendor_applications/approve"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reject" do
    it "returns http success" do
      get "/admin/vendor_applications/reject"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /request_changes" do
    it "returns http success" do
      get "/admin/vendor_applications/request_changes"
      expect(response).to have_http_status(:success)
    end
  end

end
