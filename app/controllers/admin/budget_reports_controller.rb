class Admin::BudgetReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_or_committee_member
  before_action :set_festival

  def index
    @reports = prepare_report_list
  end

  def show
    @report = BudgetReport.new(
      festival: @festival,
      start_date: params[:start_date]&.to_date || @festival.start_date || Date.current.beginning_of_month,
      end_date: params[:end_date]&.to_date || @festival.end_date || Date.current.end_of_month
    )

    @chart_data = prepare_chart_data(@report)
  end

  def dashboard
    @analytics = BudgetAnalyticsService.new(@festival)
    @dashboard_data = @analytics.generate_dashboard_data
    @efficiency_score = @analytics.budget_efficiency_score

    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end

  def analytics
    @analytics = BudgetAnalyticsService.new(@festival)
    @forecast = @analytics.forecast_analysis(6)
    @trends = @analytics.trend_analysis
    @category_analysis = @analytics.category_breakdown

    respond_to do |format|
      format.html
      format.json { render json: { forecast: @forecast, trends: @trends, categories: @category_analysis } }
    end
  end

  def export
    @analytics = BudgetAnalyticsService.new(@festival)
    format = params[:format] || "json"

    respond_to do |format_type|
      format_type.json do
        report_data = @analytics.export_analytics_report(:json)
        send_data report_data,
                  filename: "budget_report_#{@festival.name}_#{Date.current}.json",
                  type: "application/json"
      end

      format_type.csv do
        report_data = @analytics.export_analytics_report(:csv)
        send_data report_data,
                  filename: "budget_report_#{@festival.name}_#{Date.current}.csv",
                  type: "text/csv"
      end

      format_type.html do
        @report = BudgetReport.new(
          festival: @festival,
          start_date: params[:start_date]&.to_date || @festival.start_date,
          end_date: params[:end_date]&.to_date || @festival.end_date
        )

        respond_to do |format|
          format.csv do
            csv_data = @report.export_to_csv
            send_data csv_data,
                      filename: "budget_summary_#{@festival.name}_#{Date.current}.csv",
                      type: "text/csv"
          end
          format.json do
            json_data = @report.export_to_json
            send_data json_data,
                      filename: "budget_summary_#{@festival.name}_#{Date.current}.json",
                      type: "application/json"
          end
        end
      end
    end
  end

  def variance_analysis
    @analytics = BudgetAnalyticsService.new(@festival)
    @variance_data = @analytics.overview_metrics
    @category_variances = @analytics.category_breakdown.map do |category|
      {
        name: category[:name],
        budget: category[:budget_limit],
        actual: category[:actual_expenses],
        variance: category[:budget_limit] - category[:actual_expenses],
        variance_percentage: category[:budget_limit] > 0 ?
          ((category[:budget_limit] - category[:actual_expenses]) / category[:budget_limit] * 100).round(2) : 0
      }
    end

    respond_to do |format|
      format.html
      format.json { render json: { variance_data: @variance_data, category_variances: @category_variances } }
    end
  end

  def cash_flow
    @report = BudgetReport.new(
      festival: @festival,
      start_date: params[:start_date]&.to_date || 6.months.ago,
      end_date: params[:end_date]&.to_date || Date.current
    )

    @cash_flow_data = {
      monthly_expenses: @report.expenses_by_month,
      monthly_revenues: @report.revenues_by_month,
      projections: @report.cash_flow_projection(6)
    }

    respond_to do |format|
      format.html
      format.json { render json: @cash_flow_data }
    end
  end

  private

  def set_festival
    @festival = current_user.admin? || current_user.committee_member? ?
                Festival.find(params[:festival_id]) :
                current_user.festivals.find(params[:festival_id])
  end

  def ensure_admin_or_committee_member
    unless current_user.admin? || current_user.committee_member? ||
           current_user.festivals.exists?(params[:festival_id])
      redirect_to root_path, alert: "アクセス権限がありません。"
    end
  end

  def prepare_report_list
    [
      {
        name: "予算概要レポート",
        description: "全体的な予算使用状況と残高",
        path: admin_festival_budget_report_path(@festival, type: "overview"),
        icon: "chart-pie"
      },
      {
        name: "月次収支レポート",
        description: "月ごとの収入と支出の推移",
        path: admin_festival_budget_report_path(@festival, type: "monthly"),
        icon: "chart-line"
      },
      {
        name: "カテゴリ別分析",
        description: "予算カテゴリごとの詳細分析",
        path: admin_festival_budget_report_path(@festival, type: "category"),
        icon: "chart-bar"
      },
      {
        name: "予実差異分析",
        description: "予算と実績の差異分析",
        path: variance_analysis_admin_festival_budget_reports_path(@festival),
        icon: "analytics"
      },
      {
        name: "キャッシュフロー分析",
        description: "資金の流れと将来予測",
        path: cash_flow_admin_festival_budget_reports_path(@festival),
        icon: "trending-up"
      }
    ]
  end

  def prepare_chart_data(report)
    {
      budget_overview: {
        total_budget: report.total_budget_limit,
        total_expenses: report.total_expenses,
        total_revenues: report.total_revenues,
        net_balance: report.net_balance
      },
      category_expenses: report.expenses_by_category.map do |item|
        {
          name: item[:category].name,
          amount: item[:amount],
          percentage: item[:percentage]
        }
      end,
      revenue_breakdown: report.revenues_by_type.map do |item|
        {
          name: item[:type_text],
          amount: item[:amount],
          percentage: item[:percentage]
        }
      end,
      monthly_trends: {
        expenses: report.expenses_by_month,
        revenues: report.revenues_by_month
      }
    }
  end
end
