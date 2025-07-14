class Admin::VenuesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_venue, only: [ :show, :edit, :update, :destroy, :layout_editor ]
  before_action :set_festival, only: [ :index, :new, :create ]

  def index
    @venues = @festival.venues.includes(:venue_areas, :booths)
    @venues = @venues.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @venues = @venues.page(params[:page]).per(10)
  end

  def show
    @venue_areas = @venue.venue_areas.includes(:booths)
    @layout_elements = @venue.layout_elements.visible.ordered_by_layer
    @layout_data = LayoutManagementService.new(@venue).generate_layout_data
  end

  def new
    @venue = @festival.venues.build
  end

  def create
    @venue = @festival.venues.build(venue_params)

    if @venue.save
      redirect_to admin_festival_venue_path(@festival, @venue), notice: "会場が正常に作成されました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @venue.update(venue_params)
      redirect_to admin_festival_venue_path(@festival, @venue), notice: "会場が正常に更新されました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @venue.destroy
    redirect_to admin_festival_venues_path(@festival), notice: "会場が正常に削除されました。"
  end

  def layout_editor
    @layout_service = LayoutManagementService.new(@venue)
    @layout_data = @layout_service.generate_layout_data
    @venue_areas = @venue.venue_areas.includes(:booths)
    @layout_elements = @venue.layout_elements.visible.ordered_by_layer
    @available_booth_types = Booth::BOOTH_SIZES.keys
    @available_area_types = VenueArea::AREA_TYPES
    @available_element_types = LayoutElement::ELEMENT_TYPES
  end

  private

  def set_venue
    @venue = Venue.find(params[:id])
    @festival = @venue.festival
  end

  def set_festival
    @festival = Festival.find(params[:festival_id])
  end

  def venue_params
    params.require(:venue).permit(:name, :description, :capacity, :address, :latitude, :longitude, :facility_type, :contact_info)
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
