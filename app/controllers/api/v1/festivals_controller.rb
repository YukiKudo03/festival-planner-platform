class Api::V1::FestivalsController < Api::V1::BaseController
  before_action :set_festival, only: [ :show, :update, :destroy ]
  before_action :check_rate_limit, only: [ :create, :update, :destroy ]

  # GET /api/v1/festivals
  def index
    festivals = Festival.accessible_by(current_api_user)
    festivals = apply_filters(festivals, [ :search, :status, :created_after, :created_before ])
    festivals = apply_sorting(festivals, { start_date: :asc })
    festivals = paginate_collection(festivals)

    render_pagination(festivals, FestivalSerializer)
  end

  # GET /api/v1/festivals/:id
  def show
    unless @festival.accessible_by?(current_api_user)
      render_error("このフェスティバルにアクセスする権限がありません", :forbidden)
      return
    end

    render_success(FestivalSerializer.new(@festival, detailed: true).as_json)
  end

  # POST /api/v1/festivals
  def create
    unless current_api_user.can_create_festivals?
      render_error("フェスティバルを作成する権限がありません", :forbidden)
      return
    end

    @festival = Festival.new(festival_params)
    @festival.created_by = current_api_user

    if @festival.save
      # Create default budget categories
      @festival.create_default_budget_categories!

      # Add creator as admin
      @festival.add_member(current_api_user, role: "admin")

      render_success(
        FestivalSerializer.new(@festival, detailed: true).as_json,
        "フェスティバルを作成しました",
        :created
      )
    else
      render_error(
        "フェスティバルの作成に失敗しました",
        :unprocessable_entity,
        @festival.errors.full_messages
      )
    end
  end

  # PATCH/PUT /api/v1/festivals/:id
  def update
    unless @festival.can_be_modified_by?(current_api_user)
      render_error("このフェスティバルを編集する権限がありません", :forbidden)
      return
    end

    if @festival.update(festival_params)
      render_success(
        FestivalSerializer.new(@festival, detailed: true).as_json,
        "フェスティバルを更新しました"
      )
    else
      render_error(
        "フェスティバルの更新に失敗しました",
        :unprocessable_entity,
        @festival.errors.full_messages
      )
    end
  end

  # DELETE /api/v1/festivals/:id
  def destroy
    unless @festival.can_be_deleted_by?(current_api_user)
      render_error("このフェスティバルを削除する権限がありません", :forbidden)
      return
    end

    if @festival.destroy
      render_success({}, "フェスティバルを削除しました")
    else
      render_error("フェスティバルの削除に失敗しました", :unprocessable_entity)
    end
  end

  # GET /api/v1/festivals/:id/analytics
  def analytics
    unless @festival.accessible_by?(current_api_user)
      render_error("このフェスティバルにアクセスする権限がありません", :forbidden)
      return
    end

    date_range = build_date_range
    analytics_service = AnalyticsService.new(@festival, date_range)

    render_success({
      overview: analytics_service.overview_metrics,
      budget: analytics_service.budget_analytics,
      tasks: analytics_service.task_analytics,
      vendors: analytics_service.vendor_analytics,
      venue: analytics_service.venue_analytics,
      communication: analytics_service.communication_analytics,
      trends: analytics_service.trend_analytics,
      recommendations: analytics_service.recommendations
    })
  end

  # GET /api/v1/festivals/:id/dashboard
  def dashboard
    unless @festival.accessible_by?(current_api_user)
      render_error("このフェスティバルにアクセスする権限がありません", :forbidden)
      return
    end

    date_range = build_date_range
    analytics_service = AnalyticsService.new(@festival, date_range)
    dashboard_data = analytics_service.dashboard_data

    render_success(dashboard_data)
  end

  # GET /api/v1/festivals/:id/members
  def members
    unless @festival.accessible_by?(current_api_user)
      render_error("このフェスティバルにアクセスする権限がありません", :forbidden)
      return
    end

    members = @festival.festival_members.includes(:user)
    members = paginate_collection(members)

    render_pagination(members, FestivalMemberSerializer)
  end

  # POST /api/v1/festivals/:id/join
  def join
    unless @festival.public? || @festival.accessible_by?(current_api_user)
      render_error("このフェスティバルに参加する権限がありません", :forbidden)
      return
    end

    if @festival.add_member(current_api_user)
      render_success({}, "フェスティバルに参加しました")
    else
      render_error("フェスティバルへの参加に失敗しました", :unprocessable_entity)
    end
  end

  # DELETE /api/v1/festivals/:id/leave
  def leave
    membership = @festival.festival_members.find_by(user: current_api_user)

    unless membership
      render_error("このフェスティバルのメンバーではありません", :bad_request)
      return
    end

    if membership.destroy
      render_success({}, "フェスティバルから退出しました")
    else
      render_error("フェスティバルからの退出に失敗しました", :unprocessable_entity)
    end
  end

  # GET /api/v1/festivals/:id/export
  def export
    unless @festival.accessible_by?(current_api_user)
      render_error("このフェスティバルにアクセスする権限がありません", :forbidden)
      return
    end

    format = params[:format] || "json"

    case format.downcase
    when "csv"
      csv_data = FestivalExportService.new(@festival).to_csv
      send_data csv_data, filename: "festival_#{@festival.id}_#{Date.current}.csv", type: "text/csv"
    when "excel"
      excel_data = FestivalExportService.new(@festival).to_excel
      send_data excel_data, filename: "festival_#{@festival.id}_#{Date.current}.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else
      detailed_data = FestivalSerializer.new(@festival,
        detailed: true,
        include_tasks: true,
        include_vendors: true,
        include_budget: true
      ).as_json

      render_success(detailed_data)
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:id])
  end

  def festival_params
    params.require(:festival).permit(
      :name, :description, :start_date, :end_date, :location,
      :capacity, :ticket_price, :status, :website_url, :contact_email,
      :contact_phone, :budget, :public, :featured, :tags,
      venue_attributes: [ :name, :address, :capacity, :contact_info ]
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
