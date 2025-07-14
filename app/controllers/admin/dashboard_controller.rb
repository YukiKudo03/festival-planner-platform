class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_or_committee_member
  before_action :set_festival, except: [ :platform_overview ]
  before_action :set_date_range

  def show
    @analytics = AnalyticsService.new(@festival, @date_range)
    @dashboard_data = @analytics.dashboard_data

    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end

  def platform_overview
    @analytics = AnalyticsService.new(nil, @date_range)
    @dashboard_data = @analytics.dashboard_data

    respond_to do |format|
      format.html { render :platform_overview }
      format.json { render json: @dashboard_data }
    end
  end

  def budget_analytics
    @analytics = AnalyticsService.new(@festival, @date_range)
    @budget_data = @analytics.budget_analytics

    respond_to do |format|
      format.html { render partial: "budget_analytics" }
      format.json { render json: @budget_data }
    end
  end

  def task_analytics
    @analytics = AnalyticsService.new(@festival, @date_range)
    @task_data = @analytics.task_analytics

    respond_to do |format|
      format.html { render partial: "task_analytics" }
      format.json { render json: @task_data }
    end
  end

  def vendor_analytics
    @analytics = AnalyticsService.new(@festival, @date_range)
    @vendor_data = @analytics.vendor_analytics

    respond_to do |format|
      format.html { render partial: "vendor_analytics" }
      format.json { render json: @vendor_data }
    end
  end

  def venue_analytics
    @analytics = AnalyticsService.new(@festival, @date_range)
    @venue_data = @analytics.venue_analytics

    respond_to do |format|
      format.html { render partial: "venue_analytics" }
      format.json { render json: @venue_data }
    end
  end

  def communication_analytics
    @analytics = AnalyticsService.new(@festival, @date_range)
    @communication_data = @analytics.communication_analytics

    respond_to do |format|
      format.html { render partial: "communication_analytics" }
      format.json { render json: @communication_data }
    end
  end

  def time_series_data
    @analytics = AnalyticsService.new(@festival, @date_range)
    metric = params[:metric]
    period = params[:period] || "daily"

    data = @analytics.time_series_data(metric, period)

    render json: data
  end

  def forecast_data
    @analytics = AnalyticsService.new(@festival, @date_range)
    metric = params[:metric]
    periods = (params[:periods] || 30).to_i

    data = @analytics.forecast_analysis(metric, periods)

    render json: data
  end

  def comparative_data
    @analytics = AnalyticsService.new(@festival, @date_range)
    comparison_type = params[:comparison_type] || "previous_period"

    data = @analytics.comparative_analysis(comparison_type)

    render json: data
  end

  def recommendations
    @analytics = AnalyticsService.new(@festival, @date_range)
    @recommendations = @analytics.recommendations

    respond_to do |format|
      format.html { render partial: "recommendations" }
      format.json { render json: @recommendations }
    end
  end

  def export_data
    @analytics = AnalyticsService.new(@festival, @date_range)
    format = params[:format] || "json"

    case format.downcase
    when "csv"
      csv_data = generate_csv_export(@analytics)
      send_data csv_data, filename: "festival_analytics_#{Date.current}.csv", type: "text/csv"
    when "excel"
      excel_data = generate_excel_export(@analytics)
      send_data excel_data, filename: "festival_analytics_#{Date.current}.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    else
      render json: @analytics.dashboard_data
    end
  end

  private

  def set_festival
    @festival = Festival.find(params[:festival_id]) if params[:festival_id]
  end

  def set_date_range
    if params[:start_date].present? && params[:end_date].present?
      @date_range = Date.parse(params[:start_date])..Date.parse(params[:end_date])
    elsif params[:period].present?
      case params[:period]
      when "last_7_days"
        @date_range = 7.days.ago.to_date..Date.current
      when "last_30_days"
        @date_range = 30.days.ago.to_date..Date.current
      when "last_90_days"
        @date_range = 90.days.ago.to_date..Date.current
      when "this_year"
        @date_range = Date.current.beginning_of_year..Date.current.end_of_year
      else
        @date_range = nil
      end
    else
      @date_range = nil
    end
  end

  def require_admin_or_committee_member
    unless current_user.admin? || current_user.committee_member?
      redirect_to root_path, alert: "このページにアクセスする権限がありません。"
    end
  end

  def generate_csv_export(analytics)
    require "csv"

    CSV.generate(headers: true) do |csv|
      dashboard_data = analytics.dashboard_data

      csv << [ "セクション", "指標", "値", "説明" ]

      dashboard_data.each do |section, data|
        next unless data.is_a?(Hash)

        data.each do |metric, value|
          csv << [
            section.to_s.humanize,
            metric.to_s.humanize,
            format_value_for_export(value),
            get_metric_description(metric)
          ]
        end
      end
    end
  end

  def generate_excel_export(analytics)
    require "rubyXL"

    workbook = RubyXL::Workbook.new
    worksheet = workbook[0]
    worksheet.sheet_name = "Festival Analytics"

    row = 0
    headers = [ "セクション", "指標", "値", "説明" ]
    headers.each_with_index do |header, col|
      worksheet.add_cell(row, col, header)
    end

    row += 1
    dashboard_data = analytics.dashboard_data

    dashboard_data.each do |section, data|
      next unless data.is_a?(Hash)

      data.each do |metric, value|
        worksheet.add_cell(row, 0, section.to_s.humanize)
        worksheet.add_cell(row, 1, metric.to_s.humanize)
        worksheet.add_cell(row, 2, format_value_for_export(value))
        worksheet.add_cell(row, 3, get_metric_description(metric))
        row += 1
      end
    end

    workbook.stream.string
  end

  def format_value_for_export(value)
    case value
    when Numeric
      value.is_a?(Float) ? value.round(2) : value
    when Array
      value.size
    when Hash
      value.keys.join(", ")
    else
      value.to_s
    end
  end

  def get_metric_description(metric)
    descriptions = {
      total_festivals: "登録されている祭りの総数",
      active_festivals: "現在アクティブな祭りの数",
      total_vendors: "出店者の総数",
      total_revenue: "総収益額",
      completion_rate: "タスク完了率（％）",
      budget_utilization: "予算使用率（％）",
      approval_rate: "出店者承認率（％）",
      user_activity: "ユーザーアクティビティ指標"
    }

    descriptions[metric.to_sym] || "詳細な説明なし"
  end
end
