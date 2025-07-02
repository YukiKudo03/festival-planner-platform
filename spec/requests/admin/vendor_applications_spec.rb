require 'rails_helper'

RSpec.describe "Admin::VendorApplications", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:festival) { create(:festival) }
  let(:vendor_application) { create(:vendor_application, festival: festival) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/vendor_applications" do
    it "returns http success" do
      get admin_vendor_applications_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/vendor_applications/:id" do
    it "returns http success" do
      get admin_vendor_application_path(vendor_application)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/vendor_applications/:id/review" do
    it "returns http success" do
      get review_admin_vendor_application_path(vendor_application)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/vendor_applications/:id/approve" do
    it "returns http success" do
      get approve_admin_vendor_application_path(vendor_application)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/vendor_applications/:id/reject" do
    it "returns http success" do
      get reject_admin_vendor_application_path(vendor_application)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/vendor_applications/:id/request_changes" do
    it "returns http success" do
      get request_changes_admin_vendor_application_path(vendor_application)
      expect(response).to have_http_status(:success)
    end
  end

  context "when not signed in" do
    before do
      sign_out admin_user
    end

    it "redirects to sign in" do
      get admin_vendor_applications_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "when signed in as non-admin" do
    let(:regular_user) { create(:user) }
    
    before do
      sign_out admin_user
      sign_in regular_user
    end

    it "redirects due to authorization" do
      get admin_vendor_applications_path
      expect(response).to have_http_status(:redirect)
    end
  end
end
