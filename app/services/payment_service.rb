class PaymentService
  include ActiveModel::Validations

  SUPPORTED_PROVIDERS = %w[stripe paypal bank_transfer cash].freeze

  def self.available_methods
    [
      {
        id: "stripe",
        name: "クレジットカード (Stripe)",
        description: "Visa, Mastercard, JCB等の主要クレジットカード",
        fee_percentage: 3.6,
        supported_currencies: [ "JPY", "USD" ],
        min_amount: 50,
        max_amount: 999999
      },
      {
        id: "paypal",
        name: "PayPal",
        description: "PayPalアカウントまたはクレジットカード",
        fee_percentage: 3.9,
        supported_currencies: [ "JPY", "USD" ],
        min_amount: 100,
        max_amount: 999999
      },
      {
        id: "bank_transfer",
        name: "銀行振込",
        description: "銀行口座への直接振込",
        fee_percentage: 0,
        supported_currencies: [ "JPY" ],
        min_amount: 1000,
        max_amount: 10000000
      },
      {
        id: "cash",
        name: "現金支払い",
        description: "当日現金での支払い",
        fee_percentage: 0,
        supported_currencies: [ "JPY" ],
        min_amount: 100,
        max_amount: 100000
      }
    ]
  end

  def self.process_payment(payment:, provider:)
    case provider.to_s
    when "stripe"
      StripePaymentProcessor.new(payment).process
    when "paypal"
      PayPalPaymentProcessor.new(payment).process
    when "bank_transfer"
      BankTransferProcessor.new(payment).process
    when "cash"
      CashPaymentProcessor.new(payment).process
    else
      raise UnsupportedPaymentMethodError, "Unsupported payment method: #{provider}"
    end
  end

  def self.cancel_payment(payment:, reason: nil)
    case payment.payment_method
    when "stripe"
      StripePaymentProcessor.new(payment).cancel(reason)
    when "paypal"
      PayPalPaymentProcessor.new(payment).cancel(reason)
    when "bank_transfer"
      BankTransferProcessor.new(payment).cancel(reason)
    when "cash"
      CashPaymentProcessor.new(payment).cancel(reason)
    else
      { success: false, error: "Unsupported payment method for cancellation" }
    end
  end

  def self.confirm_payment(payment)
    case payment.payment_method
    when "stripe"
      StripePaymentProcessor.new(payment).confirm
    when "paypal"
      PayPalPaymentProcessor.new(payment).confirm
    when "bank_transfer"
      BankTransferProcessor.new(payment).confirm
    when "cash"
      CashPaymentProcessor.new(payment).confirm
    else
      { success: false, error: "Unsupported payment method for confirmation" }
    end
  end

  def self.validate_payment_data(payment_data)
    errors = []

    # Amount validation
    if payment_data[:amount].blank? || payment_data[:amount] <= 0
      errors << "Amount must be greater than 0"
    end

    # Payment method validation
    unless SUPPORTED_PROVIDERS.include?(payment_data[:payment_method])
      errors << "Unsupported payment method"
    end

    # Method-specific validation
    method_info = available_methods.find { |m| m[:id] == payment_data[:payment_method] }
    if method_info && payment_data[:amount].present?
      if payment_data[:amount] < method_info[:min_amount]
        errors << "Amount is below minimum for #{method_info[:name]}"
      end

      if payment_data[:amount] > method_info[:max_amount]
        errors << "Amount exceeds maximum for #{method_info[:name]}"
      end
    end

    # Currency validation
    if payment_data[:currency].present?
      method_info = available_methods.find { |m| m[:id] == payment_data[:payment_method] }
      if method_info && !method_info[:supported_currencies].include?(payment_data[:currency])
        errors << "Currency not supported for this payment method"
      end
    end

    errors
  end

  def self.calculate_fees(amount, payment_method)
    method_info = available_methods.find { |m| m[:id] == payment_method }
    return 0 unless method_info

    (amount * method_info[:fee_percentage] / 100).round(2)
  end
end

# Payment Processors
class StripePaymentProcessor
  def initialize(payment)
    @payment = payment
    @stripe_client = configure_stripe
  end

  def process
    begin
      # Create Stripe payment intent
      intent = @stripe_client.payment_intents.create({
        amount: (@payment.amount * 100).to_i, # Stripe uses cents
        currency: @payment.currency || "jpy",
        metadata: {
          festival_id: @payment.festival.id,
          user_id: @payment.user.id,
          payment_id: @payment.id
        },
        description: @payment.description
      })

      {
        success: true,
        transaction_id: intent.id,
        client_secret: intent.client_secret
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe payment error: #{e.message}"
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "Payment processing error: #{e.message}"
      { success: false, error: "Payment processing failed" }
    end
  end

  def cancel(reason = nil)
    return { success: false, error: "No transaction ID" } unless @payment.external_transaction_id

    begin
      @stripe_client.payment_intents.cancel(@payment.external_transaction_id)
      { success: true }
    rescue Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end

  def confirm
    return { success: false, error: "No transaction ID" } unless @payment.external_transaction_id

    begin
      intent = @stripe_client.payment_intents.retrieve(@payment.external_transaction_id)

      if intent.status == "succeeded"
        {
          success: true,
          confirmation_code: intent.charges.data.first&.id
        }
      else
        { success: false, error: "Payment not yet completed" }
      end
    rescue Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end

  private

  def configure_stripe
    Stripe.api_key = Rails.application.credentials.stripe[:secret_key]
    Stripe
  rescue StandardError
    raise ConfigurationError, "Stripe not properly configured"
  end
end

class PayPalPaymentProcessor
  def initialize(payment)
    @payment = payment
  end

  def process
    # PayPal API integration would go here
    # For now, return a mock successful response
    {
      success: true,
      transaction_id: "PAYPAL_#{SecureRandom.hex(8)}",
      redirect_url: "https://paypal.com/checkout/#{SecureRandom.hex(16)}"
    }
  end

  def cancel(reason = nil)
    # PayPal cancellation logic
    { success: true }
  end

  def confirm
    # PayPal confirmation logic
    {
      success: true,
      confirmation_code: "PP_#{SecureRandom.hex(8)}"
    }
  end
end

class BankTransferProcessor
  def initialize(payment)
    @payment = payment
  end

  def process
    # Generate bank transfer instructions
    transfer_code = "BT#{@payment.festival.id}#{@payment.id}#{Time.current.strftime('%Y%m%d')}"

    {
      success: true,
      transaction_id: transfer_code,
      instructions: {
        bank_name: "みずほ銀行",
        branch_name: "新宿支店",
        account_type: "普通",
        account_number: "1234567",
        account_name: "フェスティバルプラットフォーム",
        transfer_code: transfer_code,
        amount: @payment.amount,
        deadline: 7.days.from_now.strftime("%Y年%m月%d日")
      }
    }
  end

  def cancel(reason = nil)
    { success: true }
  end

  def confirm
    # Manual confirmation for bank transfers
    {
      success: true,
      confirmation_code: "BT_#{SecureRandom.hex(8)}"
    }
  end
end

class CashPaymentProcessor
  def initialize(payment)
    @payment = payment
  end

  def process
    # Cash payment is processed at the event
    receipt_number = "CASH#{@payment.festival.id}#{@payment.id}"

    {
      success: true,
      transaction_id: receipt_number,
      instructions: {
        type: "現金支払い",
        amount: @payment.amount,
        receipt_number: receipt_number,
        message: "当日会場にて現金でお支払いください"
      }
    }
  end

  def cancel(reason = nil)
    { success: true }
  end

  def confirm
    {
      success: true,
      confirmation_code: "CASH_#{SecureRandom.hex(8)}"
    }
  end
end

# Custom Error Classes
class UnsupportedPaymentMethodError < StandardError; end
class ConfigurationError < StandardError; end
