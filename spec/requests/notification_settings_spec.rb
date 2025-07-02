require 'rails_helper'

RSpec.describe "NotificationSettings", type: :request do
  let(:user) { create(:user) }
  let(:notification_setting) { create(:notification_setting, user: user) }

  before do
    sign_in user
  end

  describe "GET /notification_settings" do
    it "returns http success" do
      get notification_settings_path
      expect(response).to have_http_status(:success)
    end
  end

  context "when not signed in" do
    before do
      sign_out user
    end

    it "redirects to sign in" do
      get notification_settings_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
