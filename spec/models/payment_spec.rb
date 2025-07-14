require 'rails_helper'

RSpec.describe Payment, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival) }

  describe 'validations' do
    subject { build(:payment) }

    it { should validate_presence_of(:amount) }
    it { should validate_presence_of(:payment_method) }

    it 'validates presence of customer_email when user has no email' do
      payment = build(:payment, user: build(:user, email: nil), customer_email: nil)
      expect(payment).not_to be_valid
      expect(payment.errors[:customer_email]).to include("can't be blank")
    end

    it 'validates presence of customer_name when user has no name' do
      payment = build(:payment, user: build(:user, first_name: nil, last_name: nil), customer_name: nil)
      expect(payment).not_to be_valid
      expect(payment.errors[:customer_name]).to include("can't be blank")
    end

    it 'validates currency is included in allowed list' do
      payment = build(:payment, currency: 'INVALID')
      expect(payment).not_to be_valid
      expect(payment.errors[:currency]).to include('is not included in the list')
    end

    it 'validates amount is positive' do
      payment = build(:payment, amount: -100)
      expect(payment).not_to be_valid
      expect(payment.errors[:amount]).to include('must be greater than 0')
    end

    it 'validates email format for customer_email' do
      payment = build(:payment, customer_email: 'invalid-email')
      expect(payment).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:festival) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:status).with_values({
        pending: 'pending',
        processing: 'processing',
        completed: 'completed',
        failed: 'failed',
        cancelled: 'cancelled',
        refunded: 'refunded'
      }).backed_by_column_of_type(:string)
    end

    it do
      should define_enum_for(:payment_method).with_values({
        stripe: 'stripe',
        paypal: 'paypal',
        bank_transfer: 'bank_transfer',
        cash: 'cash'
      }).backed_by_column_of_type(:string)
    end
  end

  describe 'instance methods' do
    let(:payment) { create(:payment, amount: 5000) }

    describe '#formatted_amount' do
      it 'returns formatted amount with currency' do
        expect(payment.formatted_amount).to include('5,000')
        expect(payment.formatted_amount).to start_with('JPY')
      end
    end

    describe '#net_amount' do
      it 'returns amount minus processing fee' do
        expected_net = payment.amount - payment.processing_fee
        expect(payment.net_amount).to eq(expected_net)
      end
    end

    describe '#can_be_cancelled?' do
      context 'when status is pending' do
        let(:pending_payment) { build(:payment, status: :pending) }

        it 'returns true' do
          expect(pending_payment.can_be_cancelled?).to be true
        end
      end

      context 'when status is completed' do
        let(:completed_payment) { build(:payment, status: :completed) }

        it 'returns false' do
          expect(completed_payment.can_be_cancelled?).to be false
        end
      end
    end

    describe '#status_color' do
      it 'returns correct color for each status' do
        expect(build(:payment, status: :pending).status_color).to eq('warning')
        expect(build(:payment, status: :completed).status_color).to eq('success')
        expect(build(:payment, status: :failed).status_color).to eq('danger')
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create' do
      it 'calculates processing fee based on payment method' do
        stripe_payment = build(:payment, payment_method: :stripe, amount: 10000, processing_fee: nil)
        stripe_payment.save
        expect(stripe_payment.processing_fee).to be >= 0
      end
    end
  end
end
