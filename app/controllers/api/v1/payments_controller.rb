class Api::V1::PaymentsController < Api::V1::BaseController
  before_action :set_festival, only: [:create, :show, :update, :cancel]
  before_action :set_payment, only: [:show, :update, :cancel, :confirm]
  before_action :check_rate_limit, only: [:create, :update, :cancel]
  
  # GET /api/v1/festivals/:festival_id/payments
  def index
    payments = Payment.joins(:festival)
                     .where(festivals: { id: accessible_festival_ids })
    
    payments = apply_filters(payments, [:status, :payment_method, :created_after, :created_before])
    payments = apply_sorting(payments, { created_at: :desc })
    payments = paginate_collection(payments)
    
    render_pagination(payments, PaymentSerializer)
  end
  
  # GET /api/v1/festivals/:festival_id/payments/:id
  def show
    unless @payment.accessible_by?(current_api_user)
      render_error('この支払い情報にアクセスする権限がありません', :forbidden)
      return
    end
    
    render_success(PaymentSerializer.new(@payment, detailed: true).as_json)
  end
  
  # POST /api/v1/festivals/:festival_id/payments
  def create
    unless @festival.accessible_by?(current_api_user)
      render_error('このフェスティバルにアクセスする権限がありません', :forbidden)
      return
    end
    
    @payment = @festival.payments.build(payment_params)
    @payment.user = current_api_user
    @payment.status = 'pending'
    
    if @payment.save
      # Process payment through external service
      payment_result = process_payment(@payment)
      
      if payment_result[:success]
        @payment.update!(
          status: 'processing',
          external_transaction_id: payment_result[:transaction_id],
          processed_at: Time.current
        )
        
        render_success(
          PaymentSerializer.new(@payment, detailed: true).as_json,
          '支払い処理を開始しました',
          :created
        )
      else
        @payment.update(status: 'failed', error_message: payment_result[:error])
        render_error(
          "支払い処理に失敗しました: #{payment_result[:error]}",
          :unprocessable_entity
        )
      end
    else
      render_error(
        '支払い情報の保存に失敗しました',
        :unprocessable_entity,
        @payment.errors.full_messages
      )
    end
  end
  
  # PATCH /api/v1/festivals/:festival_id/payments/:id
  def update
    unless @payment.can_be_modified_by?(current_api_user)
      render_error('この支払い情報を変更する権限がありません', :forbidden)
      return
    end
    
    if @payment.status != 'pending'
      render_error('処理済みの支払い情報は変更できません', :bad_request)
      return
    end
    
    if @payment.update(payment_params)
      render_success(
        PaymentSerializer.new(@payment, detailed: true).as_json,
        '支払い情報を更新しました'
      )
    else
      render_error(
        '支払い情報の更新に失敗しました',
        :unprocessable_entity,
        @payment.errors.full_messages
      )
    end
  end
  
  # DELETE /api/v1/festivals/:festival_id/payments/:id/cancel
  def cancel
    unless @payment.can_be_cancelled_by?(current_api_user)
      render_error('この支払いをキャンセルする権限がありません', :forbidden)
      return
    end
    
    unless @payment.cancellable?
      render_error('この支払いはキャンセルできません', :bad_request)
      return
    end
    
    cancellation_result = cancel_payment(@payment)
    
    if cancellation_result[:success]
      @payment.update!(
        status: 'cancelled',
        cancelled_at: Time.current,
        cancellation_reason: params[:reason]
      )
      
      render_success(
        PaymentSerializer.new(@payment, detailed: true).as_json,
        '支払いをキャンセルしました'
      )
    else
      render_error(
        "支払いのキャンセルに失敗しました: #{cancellation_result[:error]}",
        :unprocessable_entity
      )
    end
  end
  
  # POST /api/v1/payments/:id/confirm
  def confirm
    unless @payment.confirmable_by?(current_api_user)
      render_error('この支払いを確認する権限がありません', :forbidden)
      return
    end
    
    confirmation_result = confirm_payment(@payment)
    
    if confirmation_result[:success]
      @payment.update!(
        status: 'completed',
        confirmed_at: Time.current,
        confirmation_code: confirmation_result[:confirmation_code]
      )
      
      # Create success notification
      create_payment_notification(@payment, 'payment_completed')
      
      render_success(
        PaymentSerializer.new(@payment, detailed: true).as_json,
        '支払いが完了しました'
      )
    else
      @payment.update(status: 'failed', error_message: confirmation_result[:error])
      render_error(
        "支払いの確認に失敗しました: #{confirmation_result[:error]}",
        :unprocessable_entity
      )
    end
  end
  
  # GET /api/v1/payments/methods
  def payment_methods
    methods = PaymentService.available_methods
    
    render_success({
      methods: methods.map do |method|
        {
          id: method[:id],
          name: method[:name],
          description: method[:description],
          fee_percentage: method[:fee_percentage],
          supported_currencies: method[:supported_currencies],
          min_amount: method[:min_amount],
          max_amount: method[:max_amount]
        }
      end
    })
  end
  
  # GET /api/v1/festivals/:festival_id/payments/summary
  def summary
    unless @festival.accessible_by?(current_api_user)
      render_error('このフェスティバルにアクセスする権限がありません', :forbidden)
      return
    end
    
    date_range = build_date_range
    payments = @festival.payments
    payments = payments.where(created_at: date_range) if date_range
    
    summary = {
      total_amount: payments.completed.sum(:amount),
      total_transactions: payments.count,
      completed_transactions: payments.completed.count,
      pending_transactions: payments.pending.count,
      failed_transactions: payments.failed.count,
      cancelled_transactions: payments.cancelled.count,
      average_transaction: payments.completed.average(:amount)&.round(2) || 0,
      payment_methods: payments.group(:payment_method).count,
      daily_totals: payments.completed
                            .group_by_day(:created_at, last: 30)
                            .sum(:amount),
      processing_fees: payments.completed.sum(:processing_fee) || 0
    }
    
    render_success(summary)
  end
  
  private
  
  def set_festival
    @festival = Festival.find(params[:festival_id]) if params[:festival_id]
  end
  
  def set_payment
    if @festival
      @payment = @festival.payments.find(params[:id])
    else
      @payment = Payment.find(params[:id])
    end
  end
  
  def payment_params
    params.require(:payment).permit(
      :amount, :payment_method, :description, :currency,
      :customer_email, :customer_name, :billing_address,
      :metadata
    )
  end
  
  def accessible_festival_ids
    if current_api_user.admin? || current_api_user.system_admin?
      Festival.pluck(:id)
    else
      current_api_user.accessible_festivals.pluck(:id)
    end
  end
  
  def process_payment(payment)
    PaymentService.process_payment(
      payment: payment,
      provider: payment.payment_method
    )
  rescue StandardError => e
    { success: false, error: e.message }
  end
  
  def cancel_payment(payment)
    PaymentService.cancel_payment(
      payment: payment,
      reason: params[:reason]
    )
  rescue StandardError => e
    { success: false, error: e.message }
  end
  
  def confirm_payment(payment)
    PaymentService.confirm_payment(payment)
  rescue StandardError => e
    { success: false, error: e.message }
  end
  
  def create_payment_notification(payment, notification_type)
    payment.user.notifications.create!(
      notification_type: notification_type,
      title: "支払いが完了しました",
      message: "#{payment.festival.name}の支払い（¥#{number_with_delimiter(payment.amount)}）が完了しました。",
      notifiable: payment
    )
  end
  
  def build_date_range
    return nil unless params[:start_date] && params[:end_date]
    
    start_date = Date.parse(params[:start_date])
    end_date = Date.parse(params[:end_date])
    
    start_date..end_date
  rescue ArgumentError
    nil
  end
end