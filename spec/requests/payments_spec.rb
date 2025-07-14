require 'rails_helper'

RSpec.describe "Payments", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:festival) { create(:festival, user: user) }
  let(:payment) { create(:payment, festival: festival, user: user) }
  let(:other_payment) { create(:payment) }


  describe "GET /festivals/:festival_id/payments" do
    let!(:festival_payment) { create(:payment, festival: festival, user: user) }
    let!(:other_festival_payment) { create(:payment, festival: festival) }

    it "returns a successful response" do
      sign_in user
      get festival_payments_path(festival)
      expect(response).to be_successful
    end

    it "displays festival payments" do
      get festival_payments_path(festival)
      expect(response.body).to include(festival_payment.description)
    end

    it "does not display payments from other festivals" do
      other_payment = create(:payment)
      get festival_payments_path(festival)
      expect(response.body).not_to include(other_payment.description)
    end

    context "when user is not festival owner" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get festival_payments_path(festival)
        expect(response).to redirect_to(festivals_path)
      end
    end

    context "with admin user" do
      before { sign_in admin }

      it "allows access to any festival's payments" do
        get festival_payments_path(festival)
        expect(response).to be_successful
      end
    end
  end

  describe "GET /festivals/:festival_id/payments/:id" do
    it "returns a successful response" do
      get festival_payment_path(festival, payment)
      expect(response).to be_successful
    end

    it "assigns the payment" do
      get festival_payment_path(festival, payment)
      expect(response.body).to include(payment.description)
    end

    context "when payment belongs to different festival" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get festival_payment_path(festival, other_payment)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when user is not payment owner" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get festival_payment_path(festival, payment)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "GET /festivals/:festival_id/payments/new" do
    it "returns a successful response" do
      get new_festival_payment_path(festival)
      expect(response).to be_successful
    end

    it "renders the new payment form" do
      get new_festival_payment_path(festival)
      expect(response.body).to include("New Payment")
    end

    context "when user cannot access festival" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get new_festival_payment_path(festival)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/payments" do
    let(:valid_attributes) do
      {
        amount: 10000,
        payment_method: "credit_card",
        description: "Festival participation fee",
        customer_email: user.email,
        customer_name: user.full_name
      }
    end

    let(:invalid_attributes) do
      {
        amount: nil,
        payment_method: "",
        description: ""
      }
    end

    context "with valid parameters" do
      it "creates a new payment" do
        expect {
          post festival_payments_path(festival), params: { payment: valid_attributes }
        }.to change(Payment, :count).by(1)
      end

      it "assigns the payment to the current user" do
        post festival_payments_path(festival), params: { payment: valid_attributes }
        expect(Payment.last.user).to eq(user)
      end

      it "assigns the payment to the festival" do
        post festival_payments_path(festival), params: { payment: valid_attributes }
        expect(Payment.last.festival).to eq(festival)
      end

      it "redirects to the created payment" do
        post festival_payments_path(festival), params: { payment: valid_attributes }
        expect(response).to redirect_to(festival_payment_path(festival, Payment.last))
      end

      it "sets a success flash message" do
        post festival_payments_path(festival), params: { payment: valid_attributes }
        expect(flash[:notice]).to be_present
      end

      it "generates a unique reference number" do
        post festival_payments_path(festival), params: { payment: valid_attributes }
        expect(Payment.last.external_transaction_id).to be_present
      end
    end

    context "with invalid parameters" do
      it "does not create a payment" do
        expect {
          post festival_payments_path(festival), params: { payment: invalid_attributes }
        }.not_to change(Payment, :count)
      end

      it "renders the new template" do
        post festival_payments_path(festival), params: { payment: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it "returns unprocessable entity status" do
        post festival_payments_path(festival), params: { payment: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user cannot access festival" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        post festival_payments_path(festival), params: { payment: valid_attributes }
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "PATCH /festivals/:festival_id/payments/:id" do
    let(:new_attributes) do
      {
        description: "Updated payment description",
        customer_name: "Updated Name"
      }
    end

    context "with valid parameters" do
      it "updates the payment" do
        patch festival_payment_path(festival, payment), params: { payment: new_attributes }
        payment.reload
        expect(payment.description).to eq("Updated payment description")
      end

      it "redirects to the payment" do
        patch festival_payment_path(festival, payment), params: { payment: new_attributes }
        expect(response).to redirect_to(festival_payment_path(festival, payment))
      end

      it "sets a success flash message" do
        patch festival_payment_path(festival, payment), params: { payment: new_attributes }
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) { { amount: -100 } }

      it "does not update the payment" do
        original_description = payment.description
        patch festival_payment_path(festival, payment), params: { payment: invalid_attributes }
        payment.reload
        expect(payment.description).to eq(original_description)
      end

      it "renders the edit template" do
        patch festival_payment_path(festival, payment), params: { payment: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end

    context "when payment is completed" do
      let(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

      it "does not allow updates" do
        patch festival_payment_path(festival, completed_payment), params: { payment: new_attributes }
        expect(response).to redirect_to(festival_payment_path(festival, completed_payment))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /festivals/:festival_id/payments/:id" do
    let!(:payment_to_delete) { create(:payment, festival: festival, user: user) }

    context "when payment is pending" do
      it "destroys the payment" do
        expect {
          delete festival_payment_path(festival, payment_to_delete)
        }.to change(Payment, :count).by(-1)
      end

      it "redirects to payments index" do
        delete festival_payment_path(festival, payment_to_delete)
        expect(response).to redirect_to(festival_payments_path(festival))
      end

      it "sets a success flash message" do
        delete festival_payment_path(festival, payment_to_delete)
        expect(flash[:notice]).to be_present
      end
    end

    context "when payment is completed" do
      let(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

      it "does not destroy the payment" do
        expect {
          delete festival_payment_path(festival, completed_payment)
        }.not_to change(Payment, :count)
      end

      it "redirects with error message" do
        delete festival_payment_path(festival, completed_payment)
        expect(response).to redirect_to(festival_payment_path(festival, completed_payment))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /festivals/:festival_id/payments/:id/process_payment" do
    let(:pending_payment) { create(:payment, festival: festival, user: user, status: :pending) }

    context "when user is admin" do
      before { sign_in admin }

      it "processes the payment" do
        post process_payment_festival_payment_path(festival, pending_payment)
        pending_payment.reload
        expect(pending_payment.status).to eq("processing")
      end

      it "sets processing timestamp" do
        post process_payment_festival_payment_path(festival, pending_payment)
        pending_payment.reload
        expect(pending_payment.processed_at).to be_present
      end

      it "redirects to payment with success message" do
        post process_payment_festival_payment_path(festival, pending_payment)
        expect(response).to redirect_to(festival_payment_path(festival, pending_payment))
        expect(flash[:notice]).to be_present
      end
    end

    context "when user is not admin" do
      it "redirects to festivals index" do
        post process_payment_festival_payment_path(festival, pending_payment)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/payments/:id/confirm" do
    let(:processing_payment) { create(:payment, festival: festival, user: user, status: :processing) }

    context "when user is admin" do
      before { sign_in admin }

      it "confirms the payment" do
        post confirm_festival_payment_path(festival, processing_payment)
        processing_payment.reload
        expect(processing_payment.status).to eq("completed")
      end

      it "sets confirmation timestamp" do
        post confirm_festival_payment_path(festival, processing_payment)
        processing_payment.reload
        expect(processing_payment.confirmed_at).to be_present
      end

      it "redirects to payment with success message" do
        post confirm_festival_payment_path(festival, processing_payment)
        expect(response).to redirect_to(festival_payment_path(festival, processing_payment))
        expect(flash[:notice]).to be_present
      end
    end

    context "when user is not admin" do
      it "redirects to festivals index" do
        post confirm_festival_payment_path(festival, processing_payment)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/payments/:id/cancel" do
    let(:pending_payment) { create(:payment, festival: festival, user: user, status: :pending) }

    it "cancels the payment" do
      post cancel_festival_payment_path(festival, pending_payment), params: {
        cancellation_reason: "User requested cancellation"
      }
      pending_payment.reload
      expect(pending_payment.status).to eq("cancelled")
    end

    it "sets cancellation timestamp and reason" do
      post cancel_festival_payment_path(festival, pending_payment), params: {
        cancellation_reason: "User requested cancellation"
      }
      pending_payment.reload
      expect(pending_payment.cancelled_at).to be_present
      expect(pending_payment.cancellation_reason).to eq("User requested cancellation")
    end

    it "redirects to payment with success message" do
      post cancel_festival_payment_path(festival, pending_payment), params: {
        cancellation_reason: "User requested cancellation"
      }
      expect(response).to redirect_to(festival_payment_path(festival, pending_payment))
      expect(flash[:notice]).to be_present
    end

    context "when payment is completed" do
      let(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

      it "does not cancel the payment" do
        post cancel_festival_payment_path(festival, completed_payment), params: {
          cancellation_reason: "User requested cancellation"
        }
        completed_payment.reload
        expect(completed_payment.status).to eq("completed")
      end
    end
  end

  describe "GET /festivals/:festival_id/payments/:id/receipt" do
    let(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

    it "returns PDF receipt" do
      get receipt_festival_payment_path(festival, completed_payment, format: :pdf)
      expect(response).to be_successful
      expect(response.content_type).to include("application/pdf")
    end

    it "includes payment details in receipt" do
      get receipt_festival_payment_path(festival, completed_payment)
      expect(response.body).to include(completed_payment.amount.to_s)
      expect(response.body).to include(completed_payment.description)
    end

    context "when payment is not completed" do
      it "redirects with error message" do
        get receipt_festival_payment_path(festival, payment)
        expect(response).to redirect_to(festival_payment_path(festival, payment))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "JSON format responses" do
    context "when requesting JSON format" do
      it "returns JSON response for index" do
        get festival_payments_path(festival), headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to include('application/json')
      end

      it "returns JSON response for show" do
        get festival_payment_path(festival, payment), headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to include('application/json')
      end

      it "includes payment data in JSON response" do
        get festival_payment_path(festival, payment), headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response['amount']).to eq(payment.amount.to_s)
        expect(json_response['status']).to eq(payment.status)
      end
    end
  end

  describe "authentication and authorization" do
    context "when user is not signed in" do
      before { sign_out user }

      it "redirects to sign in page" do
        get festival_payments_path(festival)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user does not have access to festival" do
      let(:other_user) { create(:user) }
      let(:private_festival) { create(:festival, public: false) }

      before { sign_in other_user }

      it "redirects to festivals index" do
        get festival_payments_path(private_festival)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "error handling" do
    context "when festival does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get payments_path.sub("/festivals/#{festival.id}", "/festivals/nonexistent")
        }.to raise_error(ActionController::RoutingError)
      end
    end

    context "when payment does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get festival_payment_path(festival, 'nonexistent')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "pagination and filtering" do
    before do
      create_list(:payment, 15, festival: festival, user: user)
    end

    it "paginates payments" do
      get festival_payments_path(festival)
      expect(response.body).to include("Next")
    end

    context "with status filter" do
      let!(:pending_payment) { create(:payment, festival: festival, user: user, status: :pending) }
      let!(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

      it "filters payments by status" do
        get festival_payments_path(festival), params: { status: 'pending' }
        expect(response.body).to include(pending_payment.description)
        expect(response.body).not_to include(completed_payment.description)
      end
    end

    context "with date range filter" do
      let!(:recent_payment) { create(:payment, festival: festival, user: user, created_at: 1.day.ago) }
      let!(:old_payment) { create(:payment, festival: festival, user: user, created_at: 1.month.ago) }

      it "filters payments by date range" do
        get festival_payments_path(festival), params: {
          start_date: 1.week.ago.to_date,
          end_date: Date.current
        }
        expect(response.body).to include(recent_payment.description)
        expect(response.body).not_to include(old_payment.description)
      end
    end
  end
end
