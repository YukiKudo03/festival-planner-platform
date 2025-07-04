class PaymentSerializer
  attr_reader :payment, :options
  
  def initialize(payment, options = {})
    @payment = payment
    @options = options
  end
  
  def as_json
    base_attributes.tap do |json|
      json.merge!(detailed_attributes) if options[:detailed]
      json.merge!(festival_data) if options[:include_festival]
      json.merge!(user_data) if options[:include_user]
      json.merge!(receipt_data) if options[:include_receipt]
    end
  end
  
  private
  
  def base_attributes
    {
      id: payment.id,
      amount: payment.amount,
      formatted_amount: payment.formatted_amount,
      payment_method: payment.payment_method,
      payment_method_display: payment.payment_method.humanize,
      status: payment.status,
      status_display: payment.status.humanize,
      currency: payment.currency,
      description: payment.description,
      external_transaction_id: payment.external_transaction_id,
      processing_fee: payment.processing_fee,
      net_amount: payment.net_amount,
      created_at: payment.created_at,
      updated_at: payment.updated_at,
      urls: {
        self: api_v1_festival_payment_url(payment.festival, payment),
        festival: api_v1_festival_url(payment.festival)
      }
    }
  end
  
  def detailed_attributes
    {
      customer_email: payment.customer_email,
      customer_name: payment.customer_name,
      billing_address: payment.billing_address,
      metadata: payment.metadata,
      processed_at: payment.processed_at,
      confirmed_at: payment.confirmed_at,
      cancelled_at: payment.cancelled_at,
      cancellation_reason: payment.cancellation_reason,
      error_message: payment.error_message,
      
      # Computed fields
      processing_time_seconds: payment.processing_time,
      confirmation_time_seconds: payment.confirmation_time,
      total_processing_time_seconds: payment.total_processing_time,
      
      # Status checks
      cancellable: payment.cancellable?,
      confirmable: payment.confirmable?,
      refundable: payment.refundable?,
      
      # Payment instructions for offline methods
      payment_instructions: payment.payment_instructions,
      external_payment_url: payment.external_payment_url,
      
      # Timestamps in different formats
      formatted_dates: {
        created_at: payment.created_at.strftime('%Y年%m月%d日 %H:%M'),
        processed_at: payment.processed_at&.strftime('%Y年%m月%d日 %H:%M'),
        confirmed_at: payment.confirmed_at&.strftime('%Y年%m月%d日 %H:%M'),
        cancelled_at: payment.cancelled_at&.strftime('%Y年%m月%d日 %H:%M')
      }
    }
  end
  
  def festival_data
    {
      festival: {
        id: payment.festival.id,
        name: payment.festival.name,
        description: payment.festival.description,
        start_date: payment.festival.start_date,
        end_date: payment.festival.end_date,
        location: payment.festival.location,
        status: payment.festival.status
      }
    }
  end
  
  def user_data
    {
      user: {
        id: payment.user.id,
        name: payment.user.display_name,
        email: payment.user.email,
        role: payment.user.role
      }
    }
  end
  
  def receipt_data
    {
      receipt: payment.receipt_data.merge({
        receipt_number: generate_receipt_number,
        issued_at: Time.current.strftime('%Y年%m月%d日'),
        payment_breakdown: {
          subtotal: payment.amount,
          processing_fee: payment.processing_fee,
          total: payment.amount # Note: processing fee is typically deducted, not added
        },
        payment_details: {
          transaction_id: payment.external_transaction_id,
          payment_method: payment.payment_method.humanize,
          currency: payment.currency,
          exchange_rate: payment.currency == 'JPY' ? nil : get_exchange_rate(payment.currency)
        }
      })
    }
  end
  
  def generate_receipt_number
    "#{payment.festival.id}-#{payment.id}-#{payment.created_at.strftime('%Y%m%d')}"
  end
  
  def get_exchange_rate(currency)
    # In a real implementation, this would fetch current exchange rates
    case currency
    when 'USD'
      150.0
    when 'EUR'
      165.0
    else
      1.0
    end
  end
  
  def api_v1_festival_payment_url(festival, payment)
    Rails.application.routes.url_helpers.api_v1_festival_payment_url(festival, payment)
  end
  
  def api_v1_festival_url(festival)
    Rails.application.routes.url_helpers.api_v1_festival_url(festival)
  end
end