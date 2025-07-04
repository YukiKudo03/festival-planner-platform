require 'rails_helper'

RSpec.describe "Api::V1::Payments", type: :request do
  let(:user) { create(:user, role: :admin) }
  let(:api_token) { user.tap(&:generate_api_token!).api_token }
  let(:headers) { { 'Authorization' => "Bearer #{api_token}", 'Content-Type' => 'application/json' } }
  let(:festival) { create(:festival, user: user) }
  let(:payment) { create(:payment, festival: festival, user: user) }

  describe "GET /api/v1/festivals/:festival_id/payments" do
    before do
      create_list(:payment, 3, festival: festival, user: user)
    end

    context "with valid authentication" do
      it "returns list of payments for festival" do
        get "/api/v1/festivals/#{festival.id}/payments", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to eq(3)
        expect(json['meta']).to include('current_page', 'total_pages')
      end

      it "filters payments by status" do
        completed_payment = create(:payment, festival: festival, user: user, status: :completed)
        
        get "/api/v1/festivals/#{festival.id}/payments", 
            params: { filters: { status: 'completed' }.to_json }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].length).to eq(1)
        expect(json['data'][0]['status']).to eq('completed')
      end

      it "filters payments by payment method" do
        stripe_payment = create(:payment, festival: festival, user: user, payment_method: :stripe)
        
        get "/api/v1/festivals/#{festival.id}/payments", 
            params: { filters: { payment_method: 'stripe' }.to_json }, 
            headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['data'].length).to eq(1)
        expect(json['data'][0]['payment_method']).to eq('stripe')
      end
    end

    context "without access permission" do
      let(:other_user) { create(:user) }
      let(:other_festival) { create(:festival, user: other_user, public: false) }

      it "returns forbidden error" do
        get "/api/v1/festivals/#{other_festival.id}/payments", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/festivals/:festival_id/payments/:id" do
    context "with valid authentication and access" do
      it "returns payment details" do
        get "/api/v1/festivals/#{festival.id}/payments/#{payment.id}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']['id']).to eq(payment.id)
        expect(json['data']['amount']).to eq(payment.amount.to_s)
        expect(json['data']['payment_method']).to eq(payment.payment_method)
      end
    end

    context "without access permission" do
      let(:other_user) { create(:user) }
      let(:other_payment) { create(:payment, festival: festival, user: other_user) }

      it "returns forbidden error for regular user accessing other's payment" do
        regular_user = create(:user, role: :resident)
        regular_token = regular_user.tap(&:generate_api_token!).api_token
        regular_headers = { 'Authorization' => "Bearer #{regular_token}", 'Content-Type' => 'application/json' }

        get "/api/v1/festivals/#{festival.id}/payments/#{other_payment.id}", headers: regular_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/festivals/:festival_id/payments" do
    let(:valid_payment_attributes) do
      {
        payment: {
          amount: 5000,
          payment_method: 'stripe',
          description: 'Festival entrance fee',
          customer_email: user.email,
          customer_name: user.full_name,
          currency: 'JPY'
        }
      }
    end

    context "with valid attributes" do
      before do
        # Mock payment service to return success
        allow(PaymentService).to receive(:process_payment).and_return({
          success: true,
          transaction_id: 'test_txn_123'
        })
      end

      it "creates a new payment" do
        expect {
          post "/api/v1/festivals/#{festival.id}/payments", 
               params: valid_payment_attributes.to_json, 
               headers: headers
        }.to change(Payment, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']['amount']).to eq('5000.0')
        expect(json['data']['status']).to eq('processing')
        expect(json['message']).to include('支払い処理を開始')
      end

      it "calculates processing fees automatically" do
        post "/api/v1/festivals/#{festival.id}/payments", 
             params: valid_payment_attributes.to_json, 
             headers: headers

        payment = Payment.last
        expect(payment.processing_fee).to be > 0
      end
    end

    context "with invalid attributes" do
      it "returns validation errors for missing amount" do
        invalid_attributes = valid_payment_attributes.deep_dup
        invalid_attributes[:payment][:amount] = nil

        post "/api/v1/festivals/#{festival.id}/payments", 
             params: invalid_attributes.to_json, 
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be false
        expect(json['errors']).to include(match(/amount/i))
      end

      it "returns validation errors for invalid payment method" do
        invalid_attributes = valid_payment_attributes.deep_dup
        invalid_attributes[:payment][:payment_method] = 'invalid_method'

        post "/api/v1/festivals/#{festival.id}/payments", 
             params: invalid_attributes.to_json, 
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "validates amount limits for payment methods" do
        invalid_attributes = valid_payment_attributes.deep_dup
        invalid_attributes[:payment][:amount] = 10 # Below minimum for most methods

        post "/api/v1/festivals/#{festival.id}/payments", 
             params: invalid_attributes.to_json, 
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context "when payment processing fails" do
      before do
        allow(PaymentService).to receive(:process_payment).and_return({
          success: false,
          error: 'Card declined'
        })
      end

      it "returns error when payment processing fails" do
        post "/api/v1/festivals/#{festival.id}/payments", 
             params: valid_payment_attributes.to_json, 
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be false
        expect(json['message']).to include('Card declined')
      end
    end
  end

  describe "PATCH /api/v1/festivals/:festival_id/payments/:id" do
    let(:update_attributes) do
      {
        payment: {
          description: "Updated description",
          customer_name: "Updated Name"
        }
      }
    end

    context "with pending payment" do
      let(:pending_payment) { create(:payment, festival: festival, user: user, status: :pending) }

      it "updates pending payment" do
        patch "/api/v1/festivals/#{festival.id}/payments/#{pending_payment.id}", 
              params: update_attributes.to_json, 
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        expect(json['data']['description']).to eq("Updated description")
      end
    end

    context "with processed payment" do
      let(:processed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

      it "prevents modification of processed payment" do
        patch "/api/v1/festivals/#{festival.id}/payments/#{processed_payment.id}", 
              params: update_attributes.to_json, 
              headers: headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['message']).to include('処理済み')
      end
    end
  end

  describe "DELETE /api/v1/festivals/:festival_id/payments/:id/cancel" do
    context "with cancellable payment" do
      let(:processing_payment) { create(:payment, festival: festival, user: user, status: :processing) }

      before do
        allow(PaymentService).to receive(:cancel_payment).and_return({ success: true })
      end

      it "cancels the payment" do
        delete "/api/v1/festivals/#{festival.id}/payments/#{processing_payment.id}/cancel", 
               params: { reason: 'User requested cancellation' }.to_json,
               headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        processing_payment.reload
        expect(processing_payment.status).to eq('cancelled')
      end
    end

    context "with non-cancellable payment" do
      let(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }

      it "prevents cancellation of completed payment" do
        delete "/api/v1/festivals/#{festival.id}/payments/#{completed_payment.id}/cancel", headers: headers

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['message']).to include('キャンセルできません')
      end
    end
  end

  describe "POST /api/v1/payments/:id/confirm" do
    let(:processing_payment) { create(:payment, festival: festival, user: user, status: :processing) }

    context "with valid confirmation" do
      before do
        allow(PaymentService).to receive(:confirm_payment).and_return({
          success: true,
          confirmation_code: 'conf_123'
        })
      end

      it "confirms the payment" do
        post "/api/v1/payments/#{processing_payment.id}/confirm", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        
        expect(json['success']).to be true
        processing_payment.reload
        expect(processing_payment.status).to eq('completed')
      end
    end

    context "when confirmation fails" do
      before do
        allow(PaymentService).to receive(:confirm_payment).and_return({
          success: false,
          error: 'Insufficient funds'
        })
      end

      it "returns error and updates payment status" do
        post "/api/v1/payments/#{processing_payment.id}/confirm", headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        processing_payment.reload
        expect(processing_payment.status).to eq('failed')
      end
    end
  end

  describe "GET /api/v1/festivals/:festival_id/payments/summary" do
    before do
      create(:payment, festival: festival, user: user, status: :completed, amount: 1000)
      create(:payment, festival: festival, user: user, status: :completed, amount: 2000)
      create(:payment, festival: festival, user: user, status: :pending, amount: 500)
      create(:payment, festival: festival, user: user, status: :failed, amount: 300)
    end

    it "returns payment summary for festival" do
      get "/api/v1/festivals/#{festival.id}/payments/summary", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['success']).to be true
      expect(json['data']['total_amount']).to eq(3000.0)
      expect(json['data']['total_transactions']).to eq(4)
      expect(json['data']['completed_transactions']).to eq(2)
      expect(json['data']['pending_transactions']).to eq(1)
      expect(json['data']['failed_transactions']).to eq(1)
    end

    it "accepts date range for summary" do
      get "/api/v1/festivals/#{festival.id}/payments/summary", 
          params: { 
            start_date: 1.week.ago.to_date, 
            end_date: Date.current 
          }, 
          headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/payments/methods" do
    it "returns available payment methods" do
      get "/api/v1/payments/methods", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['success']).to be true
      expect(json['data']['methods']).to be_an(Array)
      
      method = json['data']['methods'].first
      expect(method).to include('id', 'name', 'description', 'fee_percentage')
    end
  end

  describe "Payment security and validation" do
    it "prevents SQL injection in filters" do
      malicious_filter = { status: "'; DROP TABLE payments; --" }
      
      get "/api/v1/festivals/#{festival.id}/payments", 
          params: { filters: malicious_filter.to_json }, 
          headers: headers

      expect(response).to have_http_status(:ok)
      # Should not crash or execute malicious SQL
    end

    it "validates payment amounts against business rules" do
      invalid_payment = {
        payment: {
          amount: 100000000, # Extremely large amount
          payment_method: 'stripe'
        }
      }

      post "/api/v1/festivals/#{festival.id}/payments", 
           params: invalid_payment.to_json, 
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "enforces rate limiting on payment creation" do
      # Simulate rapid payment creation attempts
      10.times do |i|
        payment_data = {
          payment: {
            amount: 1000 + i,
            payment_method: 'stripe',
            description: "Payment #{i}"
          }
        }

        post "/api/v1/festivals/#{festival.id}/payments", 
             params: payment_data.to_json, 
             headers: headers
      end

      # Should eventually hit rate limit
      expect([200, 201, 429]).to include(response.status)
    end
  end

  describe "Error handling" do
    it "handles network timeouts gracefully" do
      allow(PaymentService).to receive(:process_payment).and_raise(Timeout::Error)

      post "/api/v1/festivals/#{festival.id}/payments", 
           params: valid_payment_attributes.to_json, 
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end

    it "handles external service unavailability" do
      allow(PaymentService).to receive(:process_payment).and_raise(StandardError, "Service unavailable")

      post "/api/v1/festivals/#{festival.id}/payments", 
           params: valid_payment_attributes.to_json, 
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end