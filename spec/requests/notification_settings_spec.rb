require 'rails_helper'

RSpec.describe "NotificationSettings", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/notification_settings/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/notification_settings/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/notification_settings/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/notification_settings/update"
      expect(response).to have_http_status(:success)
    end
  end

end
