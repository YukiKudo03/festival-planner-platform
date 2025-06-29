class VendorApplicationsController < ApplicationController
  before_action :set_festival, except: [:index]
  before_action :set_vendor_application, only: [:show, :edit, :update, :destroy]

  def index
    @vendor_applications = current_user.vendor_applications.includes(:festival, :user)
    authorize! :read, VendorApplication
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    authorize! :read, @vendor_application
  end

  def new
    @vendor_application = @festival.vendor_applications.build
    authorize! :create, @vendor_application
  end

  def create
    @vendor_application = @festival.vendor_applications.build(vendor_application_params)
    @vendor_application.user = current_user
    authorize! :create, @vendor_application

    if @vendor_application.save
      redirect_to @festival, notice: '出店申請が送信されました。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @vendor_application
  end

  def update
    authorize! :update, @vendor_application

    if @vendor_application.update(vendor_application_params)
      redirect_to @festival, notice: '出店申請が更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @vendor_application
    @vendor_application.destroy
    redirect_to @festival, notice: '出店申請が削除されました。'
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def set_vendor_application
    @vendor_application = @festival.vendor_applications.find(params[:id])
  end

  def vendor_application_params
    params.require(:vendor_application).permit(:business_name, :business_type, :description, :requirements, :status)
  end
end
