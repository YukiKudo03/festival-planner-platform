require 'rails_helper'

RSpec.describe "Simple Payments Test", type: :request do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }

  describe "Authentication test" do
    it "redirects when not signed in" do
      get festival_payments_path(festival)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "works when signed in" do
      sign_in user
      get festival_payments_path(festival)
      puts "Response status: #{response.status}"
      puts "Response body: #{response.body[0..500]}" if response.status != 200
      expect(response).to be_successful
    end
  end
end
