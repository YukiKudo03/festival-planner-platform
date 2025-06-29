class PublicFestivalsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  
  def index
    @festivals = Festival.where(status: 'published')
                        .includes(:user, :tasks, :vendor_applications)
                        .order(start_date: :asc)
    
    # Filter by location if provided
    if params[:location].present?
      @festivals = @festivals.where('location ILIKE ?', "%#{params[:location]}%")
    end
    
    # Filter by date range if provided
    if params[:start_date].present?
      @festivals = @festivals.where('start_date >= ?', params[:start_date])
    end
    
    if params[:end_date].present?
      @festivals = @festivals.where('end_date <= ?', params[:end_date])
    end
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @festival = Festival.find(params[:id])
    
    # Only allow published festivals for public access
    unless @festival.status == 'published'
      if user_signed_in?
        authorize! :read, @festival
      else
        flash[:alert] = 'このお祭りは現在公開されていません。'
        redirect_to public_festivals_path
        return
      end
    end
    
    @tasks = @festival.tasks.where(status: ['in_progress', 'completed'])
    @vendor_applications = @festival.vendor_applications.where(status: 'approved')
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end