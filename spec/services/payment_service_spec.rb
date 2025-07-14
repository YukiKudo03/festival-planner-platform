require 'rails_helper'

RSpec.describe PaymentService, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:payment) { create(:payment, user: user, festival: festival, amount: 5000) }

  describe '.available_methods' do
    it 'returns all supported payment methods' do
      methods = PaymentService.available_methods

      expect(methods).to be_an(Array)
      expect(methods.length).to eq(4)

      method_ids = methods.map { |m| m[:id] }
      expect(method_ids).to include('stripe', 'paypal', 'bank_transfer', 'cash')
    end

    it 'includes required information for each method' do
      methods = PaymentService.available_methods

      methods.each do |method|
        expect(method).to include(:id, :name, :description, :fee_percentage, :supported_currencies, :min_amount, :max_amount)
        expect(method[:supported_currencies]).to be_an(Array)
        expect(method[:fee_percentage]).to be_a(Numeric)
        expect(method[:min_amount]).to be_a(Numeric)
        expect(method[:max_amount]).to be_a(Numeric)
      end
    end
  end

  describe '.validate_payment_data' do
    let(:valid_payment_data) do
      {
        amount: 1000,
        payment_method: 'stripe',
        currency: 'JPY'
      }
    end

    context 'with valid payment data' do
      it 'returns empty errors array' do
        errors = PaymentService.validate_payment_data(valid_payment_data)
        expect(errors).to be_empty
      end
    end

    context 'with invalid amount' do
      it 'returns error for zero amount' do
        data = valid_payment_data.merge(amount: 0)
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Amount must be greater than 0')
      end

      it 'returns error for negative amount' do
        data = valid_payment_data.merge(amount: -100)
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Amount must be greater than 0')
      end

      it 'returns error for blank amount' do
        data = valid_payment_data.merge(amount: nil)
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Amount must be greater than 0')
      end
    end

    context 'with invalid payment method' do
      it 'returns error for unsupported payment method' do
        data = valid_payment_data.merge(payment_method: 'invalid_method')
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Unsupported payment method')
      end
    end

    context 'with amount below minimum' do
      it 'returns error for Stripe minimum' do
        data = valid_payment_data.merge(amount: 25, payment_method: 'stripe')
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Amount is below minimum for クレジットカード (Stripe)')
      end

      it 'returns error for bank transfer minimum' do
        data = valid_payment_data.merge(amount: 500, payment_method: 'bank_transfer')
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Amount is below minimum for 銀行振込')
      end
    end

    context 'with amount above maximum' do
      it 'returns error for cash maximum' do
        data = valid_payment_data.merge(amount: 150000, payment_method: 'cash')
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Amount exceeds maximum for 現金支払い')
      end
    end

    context 'with unsupported currency' do
      it 'returns error for EUR with bank transfer' do
        data = valid_payment_data.merge(currency: 'EUR', payment_method: 'bank_transfer')
        errors = PaymentService.validate_payment_data(data)
        expect(errors).to include('Currency not supported for this payment method')
      end
    end
  end

  describe '.calculate_fees' do
    it 'calculates Stripe fees correctly' do
      fee = PaymentService.calculate_fees(1000, 'stripe')
      expect(fee).to eq(36.0) # 1000 * 3.6%
    end

    it 'calculates PayPal fees correctly' do
      fee = PaymentService.calculate_fees(1000, 'paypal')
      expect(fee).to eq(39.0) # 1000 * 3.9%
    end

    it 'returns zero fees for bank transfer' do
      fee = PaymentService.calculate_fees(1000, 'bank_transfer')
      expect(fee).to eq(0)
    end

    it 'returns zero fees for cash payment' do
      fee = PaymentService.calculate_fees(1000, 'cash')
      expect(fee).to eq(0)
    end

    it 'returns zero for unsupported payment method' do
      fee = PaymentService.calculate_fees(1000, 'unknown_method')
      expect(fee).to eq(0)
    end
  end

  describe '.process_payment' do
    context 'with Stripe payment' do
      it 'calls StripePaymentProcessor' do
        processor_double = instance_double(StripePaymentProcessor)
        expect(StripePaymentProcessor).to receive(:new).with(payment).and_return(processor_double)
        expect(processor_double).to receive(:process).and_return({ success: true })

        result = PaymentService.process_payment(payment: payment, provider: 'stripe')
        expect(result[:success]).to be true
      end
    end

    context 'with PayPal payment' do
      it 'calls PayPalPaymentProcessor' do
        processor_double = instance_double(PayPalPaymentProcessor)
        expect(PayPalPaymentProcessor).to receive(:new).with(payment).and_return(processor_double)
        expect(processor_double).to receive(:process).and_return({ success: true })

        result = PaymentService.process_payment(payment: payment, provider: 'paypal')
        expect(result[:success]).to be true
      end
    end

    context 'with bank transfer payment' do
      it 'calls BankTransferProcessor' do
        processor_double = instance_double(BankTransferProcessor)
        expect(BankTransferProcessor).to receive(:new).with(payment).and_return(processor_double)
        expect(processor_double).to receive(:process).and_return({ success: true })

        result = PaymentService.process_payment(payment: payment, provider: 'bank_transfer')
        expect(result[:success]).to be true
      end
    end

    context 'with cash payment' do
      it 'calls CashPaymentProcessor' do
        processor_double = instance_double(CashPaymentProcessor)
        expect(CashPaymentProcessor).to receive(:new).with(payment).and_return(processor_double)
        expect(processor_double).to receive(:process).and_return({ success: true })

        result = PaymentService.process_payment(payment: payment, provider: 'cash')
        expect(result[:success]).to be true
      end
    end

    context 'with unsupported payment method' do
      it 'raises UnsupportedPaymentMethodError' do
        expect {
          PaymentService.process_payment(payment: payment, provider: 'unsupported')
        }.to raise_error(UnsupportedPaymentMethodError, 'Unsupported payment method: unsupported')
      end
    end
  end

  describe '.cancel_payment' do
    context 'with supported payment method' do
      it 'calls appropriate processor cancel method' do
        payment.update!(payment_method: 'stripe')
        processor_double = instance_double(StripePaymentProcessor)
        expect(StripePaymentProcessor).to receive(:new).with(payment).and_return(processor_double)
        expect(processor_double).to receive(:cancel).with('test reason').and_return({ success: true })

        result = PaymentService.cancel_payment(payment: payment, reason: 'test reason')
        expect(result[:success]).to be true
      end
    end

    context 'with unsupported payment method' do
      it 'returns error for unsupported method' do
        # Use update_column to bypass enum validation
        payment.update_column(:payment_method, 'unsupported')

        result = PaymentService.cancel_payment(payment: payment)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Unsupported payment method for cancellation')
      end
    end
  end

  describe '.confirm_payment' do
    context 'with supported payment method' do
      it 'calls appropriate processor confirm method' do
        payment.update!(payment_method: 'stripe')
        processor_double = instance_double(StripePaymentProcessor)
        expect(StripePaymentProcessor).to receive(:new).with(payment).and_return(processor_double)
        expect(processor_double).to receive(:confirm).and_return({ success: true })

        result = PaymentService.confirm_payment(payment)
        expect(result[:success]).to be true
      end
    end

    context 'with unsupported payment method' do
      it 'returns error for unsupported method' do
        # Use update_column to bypass enum validation
        payment.update_column(:payment_method, 'unsupported')

        result = PaymentService.confirm_payment(payment)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Unsupported payment method for confirmation')
      end
    end
  end
end

RSpec.describe BankTransferProcessor, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:payment) { create(:payment, user: user, festival: festival, amount: 10000) }
  let(:processor) { BankTransferProcessor.new(payment) }

  describe '#process' do
    it 'generates bank transfer instructions' do
      result = processor.process

      expect(result[:success]).to be true
      expect(result[:transaction_id]).to be_present
      expect(result[:instructions]).to include(:bank_name, :branch_name, :account_type, :account_number)
      expect(result[:instructions][:amount]).to eq(10000)
      expect(result[:instructions][:transfer_code]).to be_present
    end

    it 'generates unique transfer codes' do
      processor1 = BankTransferProcessor.new(payment)
      processor2 = BankTransferProcessor.new(create(:payment, user: user, festival: festival))

      result1 = processor1.process
      result2 = processor2.process

      expect(result1[:transaction_id]).not_to eq(result2[:transaction_id])
    end
  end

  describe '#cancel' do
    it 'returns success for bank transfer cancellation' do
      result = processor.cancel('Customer request')
      expect(result[:success]).to be true
    end
  end

  describe '#confirm' do
    it 'returns confirmation for bank transfer' do
      result = processor.confirm
      expect(result[:success]).to be true
      expect(result[:confirmation_code]).to be_present
    end
  end
end

RSpec.describe CashPaymentProcessor, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:payment) { create(:payment, user: user, festival: festival, amount: 5000) }
  let(:processor) { CashPaymentProcessor.new(payment) }

  describe '#process' do
    it 'generates cash payment instructions' do
      result = processor.process

      expect(result[:success]).to be true
      expect(result[:transaction_id]).to be_present
      expect(result[:instructions]).to include(:type, :amount, :receipt_number, :message)
      expect(result[:instructions][:amount]).to eq(5000)
      expect(result[:instructions][:type]).to eq('現金支払い')
    end
  end

  describe '#cancel' do
    it 'returns success for cash payment cancellation' do
      result = processor.cancel
      expect(result[:success]).to be true
    end
  end

  describe '#confirm' do
    it 'returns confirmation for cash payment' do
      result = processor.confirm
      expect(result[:success]).to be true
      expect(result[:confirmation_code]).to be_present
    end
  end
end

RSpec.describe PayPalPaymentProcessor, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:payment) { create(:payment, user: user, festival: festival, amount: 3000) }
  let(:processor) { PayPalPaymentProcessor.new(payment) }

  describe '#process' do
    it 'returns mock PayPal response' do
      result = processor.process

      expect(result[:success]).to be true
      expect(result[:transaction_id]).to start_with('PAYPAL_')
      expect(result[:redirect_url]).to include('paypal.com')
    end
  end

  describe '#cancel' do
    it 'returns success for PayPal cancellation' do
      result = processor.cancel
      expect(result[:success]).to be true
    end
  end

  describe '#confirm' do
    it 'returns confirmation for PayPal payment' do
      result = processor.confirm
      expect(result[:success]).to be true
      expect(result[:confirmation_code]).to start_with('PP_')
    end
  end
end
