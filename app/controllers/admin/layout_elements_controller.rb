class Admin::LayoutElementsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_venue
  before_action :set_layout_element, only: [ :show, :edit, :update, :destroy, :update_position ]

  def index
    @layout_elements = @venue.layout_elements.visible.ordered_by_layer
    respond_to do |format|
      format.html
      format.json { render json: @layout_elements }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @layout_element }
    end
  end

  def new
    @layout_element = @venue.layout_elements.build
  end

  def create
    @layout_element = @venue.layout_elements.build(layout_element_params)

    respond_to do |format|
      if @layout_element.save
        format.html { redirect_to admin_venue_layout_editor_path(@venue), notice: "レイアウト要素が正常に作成されました。" }
        format.json { render json: @layout_element, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @layout_element.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @layout_element.update(layout_element_params)
        format.html { redirect_to admin_venue_layout_editor_path(@venue), notice: "レイアウト要素が正常に更新されました。" }
        format.json { render json: @layout_element }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @layout_element.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @layout_element.destroy
    respond_to do |format|
      format.html { redirect_to admin_venue_layout_editor_path(@venue), notice: "レイアウト要素が正常に削除されました。" }
      format.json { head :no_content }
    end
  end

  def update_position
    position_params = params.require(:layout_element).permit(:x_position, :y_position, :width, :height, :rotation)

    respond_to do |format|
      if @layout_element.update(position_params)
        # Check for overlaps after position update
        layout_service = LayoutManagementService.new(@venue)
        overlaps = layout_service.detect_overlaps

        format.json {
          render json: {
            layout_element: @layout_element,
            overlaps: overlaps.select { |overlap|
              overlap[:element1][:id] == @layout_element.id || overlap[:element2][:id] == @layout_element.id
            }
          }
        }
      else
        format.json { render json: @layout_element.errors, status: :unprocessable_entity }
      end
    end
  end

  def bulk_update
    updates = params.require(:layout_elements).values

    ActiveRecord::Base.transaction do
      updates.each do |update_params|
        element = @venue.layout_elements.find(update_params[:id])
        element.update!(update_params.except(:id))
      end
    end

    layout_service = LayoutManagementService.new(@venue)
    overlaps = layout_service.detect_overlaps

    respond_to do |format|
      format.json { render json: { success: true, overlaps: overlaps } }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_venue
    @venue = Venue.find(params[:venue_id])
  end

  def set_layout_element
    @layout_element = @venue.layout_elements.find(params[:id])
  end

  def layout_element_params
    params.require(:layout_element).permit(:element_type, :name, :description, :x_position, :y_position,
                                           :width, :height, :rotation, :color, :layer, :locked, :visible,
                                           properties: {})
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
