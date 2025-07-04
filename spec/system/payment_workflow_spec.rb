require 'rails_helper'

RSpec.describe "Payment Workflow", type: :system do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, public: true) }
  
  before do
    driven_by(:rack_test)
    sign_in user
  end

  describe "Payment Creation Process" do
    it "allows user to create payment for festival participation" do
      visit festival_path(festival)
      
      # Navigate to payment creation
      click_link "参加申し込み" # Assuming there's a participation link
      
      # Fill payment form
      fill_in "支払い金額", with: "5000"
      select "クレジットカード (Stripe)", from: "決済方法"
      fill_in "説明", with: "Festival participation fee"
      
      # Mock payment service success
      allow(PaymentService).to receive(:process_payment).and_return({
        success: true,
        transaction_id: 'test_txn_123'
      })
      
      click_button "支払いを開始"
      
      expect(page).to have_content("支払い処理を開始しました")
      expect(page).to have_content("test_txn_123")
      
      # Verify payment record created
      payment = Payment.last
      expect(payment.user).to eq(user)
      expect(payment.festival).to eq(festival)
      expect(payment.amount).to eq(5000)
      expect(payment.status).to eq('processing')
    end

    it "validates payment amount requirements" do
      visit new_festival_payment_path(festival)
      
      # Try to submit payment with invalid amount
      fill_in "支払い金額", with: "10" # Below minimum
      select "クレジットカード (Stripe)", from: "決済方法"
      
      click_button "支払いを開始"
      
      expect(page).to have_content("最小額")
      expect(page).to have_content("以上である必要があります")
    end

    it "shows different payment methods with their requirements" do
      visit new_festival_payment_path(festival)
      
      # Check that all payment methods are available
      expect(page).to have_select("決済方法", with_options: [
        "クレジットカード (Stripe)",
        "PayPal", 
        "銀行振込",
        "現金支払い"
      ])
      
      # Selecting bank transfer should show additional requirements
      select "銀行振込", from: "決済方法"
      expect(page).to have_content("お名前")
    end
  end

  describe "Payment Status Updates" do
    let(:payment) { create(:payment, festival: festival, user: user, status: :processing) }

    it "displays payment status and allows status updates for authorized users" do
      visit festival_payment_path(festival, payment)
      
      expect(page).to have_content("支払い詳細")
      expect(page).to have_content("処理中")
      expect(page).to have_content(payment.formatted_amount)
      
      # User should see cancel option for processing payment
      expect(page).to have_button("キャンセル")
    end

    it "allows payment cancellation when appropriate" do
      visit festival_payment_path(festival, payment)
      
      # Mock cancellation service
      allow(PaymentService).to receive(:cancel_payment).and_return({ success: true })
      
      click_button "キャンセル"
      fill_in "キャンセル理由", with: "Changed my mind"
      click_button "確認"
      
      expect(page).to have_content("支払いをキャンセルしました")
      
      payment.reload
      expect(payment.status).to eq('cancelled')
    end

    it "prevents cancellation of completed payments" do
      completed_payment = create(:payment, festival: festival, user: user, status: :completed)
      
      visit festival_payment_path(festival, completed_payment)
      
      expect(page).not_to have_button("キャンセル")
      expect(page).to have_content("完了")
    end
  end

  describe "Payment Confirmation Flow" do
    context "for admin users" do
      let(:admin_user) { create(:user, role: :admin) }
      let(:processing_payment) { create(:payment, festival: festival, user: user, status: :processing) }
      
      before { sign_in admin_user }

      it "allows admin to confirm payments" do
        visit admin_festival_payment_path(festival, processing_payment)
        
        # Mock confirmation service
        allow(PaymentService).to receive(:confirm_payment).and_return({
          success: true,
          confirmation_code: 'conf_123'
        })
        
        click_button "支払いを確認"
        
        expect(page).to have_content("支払いが完了しました")
        
        processing_payment.reload
        expect(processing_payment.status).to eq('completed')
        expect(processing_payment.confirmation_code).to eq('conf_123')
      end

      it "handles confirmation failures gracefully" do
        visit admin_festival_payment_path(festival, processing_payment)
        
        allow(PaymentService).to receive(:confirm_payment).and_return({
          success: false,
          error: 'Insufficient funds'
        })
        
        click_button "支払いを確認"
        
        expect(page).to have_content("確認に失敗しました")
        expect(page).to have_content("Insufficient funds")
        
        processing_payment.reload
        expect(processing_payment.status).to eq('failed')
      end
    end
  end

  describe "Bank Transfer Workflow" do
    it "provides bank transfer instructions" do
      visit new_festival_payment_path(festival)
      
      fill_in "支払い金額", with: "10000"
      select "銀行振込", from: "決済方法"
      fill_in "お名前", with: "田中太郎"
      
      click_button "支払いを開始"
      
      expect(page).to have_content("銀行振込のご案内")
      expect(page).to have_content("みずほ銀行")
      expect(page).to have_content("振込コード")
      expect(page).to have_content("振込期限")
      
      # Check that payment is created with pending status
      payment = Payment.last
      expect(payment.status).to eq('pending')
      expect(payment.payment_instructions).to include('bank_name')
    end

    it "sends bank transfer instructions email" do
      visit new_festival_payment_path(festival)
      
      fill_in "支払い金額", with: "10000"
      select "銀行振込", from: "決済方法"
      fill_in "お名前", with: "田中太郎"
      
      expect {
        click_button "支払いを開始"
      }.to have_enqueued_mail(PaymentMailer, :bank_transfer_instructions)
    end
  end

  describe "Cash Payment Workflow" do
    it "provides cash payment instructions" do
      visit new_festival_payment_path(festival)
      
      fill_in "支払い金額", with: "3000"
      select "現金支払い", from: "決済方法"
      
      click_button "支払いを開始"
      
      expect(page).to have_content("現金支払い")
      expect(page).to have_content("当日会場にて")
      expect(page).to have_content("領収書番号")
      
      payment = Payment.last
      expect(payment.status).to eq('pending')
      expect(payment.payment_instructions).to include('type')
    end
  end

  describe "Payment History and Receipts" do
    let!(:completed_payment) { create(:payment, festival: festival, user: user, status: :completed) }
    let!(:pending_payment) { create(:payment, festival: festival, user: user, status: :pending) }

    it "displays user's payment history" do
      visit user_payments_path
      
      expect(page).to have_content("支払い履歴")
      expect(page).to have_content(completed_payment.formatted_amount)
      expect(page).to have_content(pending_payment.formatted_amount)
      expect(page).to have_content("完了")
      expect(page).to have_content("未完了")
    end

    it "allows downloading receipt for completed payments" do
      visit festival_payment_path(festival, completed_payment)
      
      expect(page).to have_link("領収書をダウンロード")
      
      # Mock PDF generation
      allow(PaymentMailer).to receive(:payment_receipt).and_return(double(deliver_later: true))
      
      click_link "領収書をダウンロード"
      expect(page).to have_content("領収書を送信しました")
    end

    it "does not show receipt option for incomplete payments" do
      visit festival_payment_path(festival, pending_payment)
      
      expect(page).not_to have_link("領収書をダウンロード")
    end
  end

  describe "Payment Security" do
    it "prevents access to other users' payments" do
      other_user = create(:user)
      other_payment = create(:payment, festival: festival, user: other_user)
      
      visit festival_payment_path(festival, other_payment)
      
      expect(page).to have_content("権限がありません")
      expect(current_path).to eq(root_path)
    end

    it "validates CSRF tokens on payment submission" do
      # This would require more sophisticated testing setup
      # to simulate CSRF attack scenarios
    end

    it "sanitizes payment descriptions to prevent XSS" do
      visit new_festival_payment_path(festival)
      
      malicious_script = "<script>alert('XSS')</script>"
      
      fill_in "支払い金額", with: "5000"
      select "クレジットカード (Stripe)", from: "決済方法"
      fill_in "説明", with: malicious_script
      
      allow(PaymentService).to receive(:process_payment).and_return({
        success: true,
        transaction_id: 'test_txn_123'
      })
      
      click_button "支払いを開始"
      
      # Script should be escaped, not executed
      expect(page.html).to include("&lt;script&gt;")
      expect(page.html).not_to include("<script>")
    end
  end

  describe "Error Handling" do
    it "handles payment service unavailability gracefully" do
      visit new_festival_payment_path(festival)
      
      fill_in "支払い金額", with: "5000"
      select "クレジットカード (Stripe)", from: "決済方法"
      
      # Simulate service unavailability
      allow(PaymentService).to receive(:process_payment).and_raise(StandardError, "Service unavailable")
      
      click_button "支払いを開始"
      
      expect(page).to have_content("支払い処理に失敗しました")
      expect(page).to have_content("しばらく時間をおいて")
    end

    it "handles network timeouts appropriately" do
      visit new_festival_payment_path(festival)
      
      fill_in "支払い金額", with: "5000"
      select "クレジットカード (Stripe)", from: "決済方法"
      
      allow(PaymentService).to receive(:process_payment).and_raise(Timeout::Error)
      
      click_button "支払いを開始"
      
      expect(page).to have_content("タイムアウト")
      expect(page).to have_content("再度お試しください")
    end
  end

  describe "Mobile Payment Experience" do
    it "provides mobile-optimized payment interface", :js do
      # Would require JavaScript driver
      page.driver.browser.manage.window.resize_to(375, 667)
      
      visit new_festival_payment_path(festival)
      
      expect(page).to have_css(".payment-form.mobile-optimized")
      expect(page).to have_button("支払いを開始")
    end
  end
end