require 'rails_helper'

RSpec.describe "Festival Platform Integration Tests", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:festival) { create(:festival, user: user) }

  describe "Basic authentication and navigation" do
    it "allows authenticated user access to festival payments" do
      sign_in user
      get festival_payments_path(festival)
      expect(response).to be_successful
    end

    it "redirects unauthenticated user to login" do
      get festival_payments_path(festival)
      expect(response).to redirect_to(new_user_session_path)
    end

    it "allows admin access to all festivals" do
      sign_in admin
      get festival_payments_path(festival)
      expect(response).to be_successful
    end
  end

  describe "Payment workflow integration" do
    before { sign_in user }

    it "can create and view a payment" do
      # Create payment
      post festival_payments_path(festival), params: {
        payment: {
          amount: 10000,
          payment_method: "credit_card",
          description: "Festival participation fee",
          customer_email: user.email,
          customer_name: user.full_name
        }
      }
      
      expect(response).to redirect_to(festival_payment_path(festival, Payment.last))
      
      # View created payment
      follow_redirect!
      expect(response).to be_successful
      expect(response.body).to include("Festival participation fee")
    end

    it "handles payment validation errors" do
      post festival_payments_path(festival), params: {
        payment: {
          amount: nil,
          payment_method: "",
          description: ""
        }
      }
      
      expect(response).to render_template(:new)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "Festival management integration" do
    before { sign_in user }

    it "can access festival overview" do
      get festival_path(festival)
      expect(response).to be_successful
    end

    it "can access payment management" do
      get new_festival_payment_path(festival)
      expect(response).to be_successful
    end
  end

  describe "Cross-functionality integration" do
    let!(:payment) { create(:payment, festival: festival, user: user) }
    
    before { sign_in user }

    it "integrates festival and payment data correctly" do
      get festival_payments_path(festival)
      expect(response.body).to include(payment.description)
      expect(response.body).to include(festival.name)
    end
  end
end