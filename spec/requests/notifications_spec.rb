require 'rails_helper'

RSpec.describe "Notifications", type: :request do
  let(:user) { create(:user) }
  let(:notification) { create(:notification, recipient: user) }

  before do
    sign_in user
  end

  describe "GET /notifications" do
    it "returns http success" do
      get notifications_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /notifications/:id" do
    it "returns http success" do
      get notification_path(notification)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /notifications/:id" do
    it "returns http success" do
      patch notification_path(notification)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /notifications/:id" do
    it "returns http success" do
      delete notification_path(notification)
      expect(response).to have_http_status(:redirect)
    end
  end

  context "when not signed in" do
    before do
      sign_out user
    end

    it "redirects to sign in" do
      get notifications_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
