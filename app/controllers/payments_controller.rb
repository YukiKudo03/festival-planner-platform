class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_payment, only: [ :show, :edit, :update, :destroy, :process_payment, :confirm, :cancel, :receipt ]
  before_action :check_festival_access!, except: [ :receipt ]
  before_action :check_payment_owner!, only: [ :show, :edit, :update, :destroy, :cancel ]
  before_action :check_admin_access!, only: [ :process_payment, :confirm ]

  def index
    @payments = current_payments.includes(:user)

    # Apply filters
    @payments = @payments.where(status: params[:status]) if params[:status].present?
    @payments = @payments.where(created_at: params[:start_date]..params[:end_date]) if params[:start_date].present? && params[:end_date].present?

    respond_to do |format|
      format.html
      format.json { render json: @payments }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @payment }
    end
  end

  def new
    @payment = @festival.payments.build
  end

  def create
    @payment = @festival.payments.build(payment_params)
    @payment.user = current_user
    @payment.external_transaction_id = generate_transaction_id

    if @payment.save
      redirect_to festival_payment_path(@festival, @payment), notice: "Payment was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to festival_payment_path(@festival, @payment), alert: "Cannot edit completed payments." if @payment.completed?
  end

  def update
    if @payment.completed?
      redirect_to festival_payment_path(@festival, @payment), alert: "Cannot update completed payments."
      return
    end

    if @payment.update(payment_params)
      redirect_to festival_payment_path(@festival, @payment), notice: "Payment was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @payment.completed?
      redirect_to festival_payment_path(@festival, @payment), alert: "Cannot delete completed payments."
    else
      @payment.destroy
      redirect_to festival_payments_path(@festival), notice: "Payment was successfully cancelled."
    end
  end

  def process_payment
    if @payment.update(status: :processing, processed_at: Time.current)
      redirect_to festival_payment_path(@festival, @payment), notice: "Payment is now being processed."
    else
      redirect_to festival_payment_path(@festival, @payment), alert: "Failed to process payment."
    end
  end

  def confirm
    if @payment.update(status: :completed, confirmed_at: Time.current)
      redirect_to festival_payment_path(@festival, @payment), notice: "Payment has been confirmed."
    else
      redirect_to festival_payment_path(@festival, @payment), alert: "Failed to confirm payment."
    end
  end

  def cancel
    if @payment.completed?
      redirect_to festival_payment_path(@festival, @payment), alert: "Cannot cancel completed payments."
    else
      @payment.update(
        status: :cancelled,
        cancelled_at: Time.current,
        cancellation_reason: params[:cancellation_reason]
      )
      redirect_to festival_payment_path(@festival, @payment), notice: "Payment has been cancelled."
    end
  end

  def receipt
    unless @payment.completed?
      redirect_to festival_payment_path(@festival, @payment), alert: "Receipt only available for completed payments."
      return
    end

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "payment_receipt_#{@payment.id}",
               template: "payments/receipt",
               layout: "pdf"
      end
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_payment
    @payment = @festival.payments.find(params[:id])
  end

  def check_festival_access!
    unless @festival.accessible_by?(current_user)
      redirect_to festivals_path, alert: "You do not have access to this festival."
    end
  end

  def check_payment_owner!
    unless @payment.user == current_user || @festival.can_be_modified_by?(current_user) || current_user.admin?
      redirect_to festivals_path, alert: "You do not have access to this payment."
    end
  end

  def check_admin_access!
    unless current_user.admin? || current_user.committee_member?
      redirect_to festivals_path, alert: "You do not have permission to perform this action."
    end
  end

  def current_payments
    if @festival.can_be_modified_by?(current_user) || current_user.admin?
      @festival.payments
    else
      @festival.payments.where(user: current_user)
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :payment_method, :description, :customer_email, :customer_name, :billing_address)
  end

  def generate_transaction_id
    "PAY-#{@festival.id}-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end
end
