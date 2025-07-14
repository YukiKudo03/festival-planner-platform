class Admin::VendorApplicationAnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  # GET /admin/vendor_application_analytics
  def index
    @date_range = parse_date_range
    @analytics = VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)

    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # GET /admin/vendor_application_analytics/dashboard
  def dashboard
    @quick_stats = generate_quick_stats
    @recent_applications = VendorApplication.includes(:festival, :user)
                                           .recent
                                           .limit(10)
    @overdue_applications = VendorApplication.joins(:festival)
                                            .where("vendor_applications.review_deadline < ?", Time.current)
                                            .where(status: [ :submitted, :under_review ])
                                            .includes(:festival, :user)
                                            .limit(10)
    @reviewer_workloads = calculate_reviewer_workloads
  end

  # GET /admin/vendor_application_analytics/performance
  def performance
    @date_range = parse_date_range
    @performance_data = VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:performance_metrics]
    @reviewer_performance = VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:reviewer_performance]

    respond_to do |format|
      format.html
      format.json { render json: { performance: @performance_data, reviewers: @reviewer_performance } }
    end
  end

  # GET /admin/vendor_application_analytics/bottlenecks
  def bottlenecks
    @date_range = parse_date_range
    @bottleneck_data = VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:bottleneck_analysis]
    @workflow_efficiency = VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:workflow_efficiency]

    respond_to do |format|
      format.html
      format.json { render json: { bottlenecks: @bottleneck_data, efficiency: @workflow_efficiency } }
    end
  end

  # GET /admin/vendor_application_analytics/predictions
  def predictions
    @date_range = parse_date_range
    @prediction_data = VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:prediction_metrics]
    @trends = generate_trend_analysis
    @capacity_forecast = generate_capacity_forecast

    respond_to do |format|
      format.html
      format.json { render json: { predictions: @prediction_data, trends: @trends, forecast: @capacity_forecast } }
    end
  end

  # GET /admin/vendor_application_analytics/export
  def export
    @date_range = parse_date_range
    @export_data = prepare_export_data

    respond_to do |format|
      format.csv do
        headers["Content-Disposition"] = "attachment; filename=\"vendor_application_analytics_#{Date.current}.csv\""
        headers["Content-Type"] = "text/csv"
      end
      format.json { render json: @export_data }
      format.xlsx do
        response.headers["Content-Disposition"] = "attachment; filename=\"vendor_application_analytics_#{Date.current}.xlsx\""
      end
    end
  end

  # GET /admin/vendor_application_analytics/timeline/:id
  def timeline
    @application = VendorApplication.find(params[:id])
    @timeline = VendorApplicationWorkflowService.new.generate_application_timeline(@application)
    @suggestions = VendorApplicationWorkflowService.new.suggest_reviewer_actions(@application)
    @score = VendorApplicationWorkflowService.new.calculate_application_score(@application)

    respond_to do |format|
      format.html
      format.json {
        render json: {
          timeline: @timeline,
          suggestions: @suggestions,
          score: @score,
          application: serialize_application(@application)
        }
      }
    end
  end

  # POST /admin/vendor_application_analytics/bulk_process
  def bulk_process
    application_ids = params[:application_ids] || []
    action = params[:action]

    if application_ids.empty?
      return render json: { error: "No applications selected" }, status: :bad_request
    end

    process_params = {
      reviewer: current_user,
      comment: params[:comment],
      conditions: params[:conditions]
    }

    results = VendorApplicationWorkflowService.new.bulk_process_applications(
      application_ids,
      action,
      process_params
    )

    respond_to do |format|
      format.json { render json: results }
      format.html do
        if results[:success_count] > 0
          redirect_to admin_vendor_applications_path,
                     notice: "#{results[:success_count]}件の申請を処理しました。"
        else
          redirect_to admin_vendor_applications_path,
                     alert: "処理に失敗しました: #{results[:errors].join(', ')}"
        end
      end
    end
  end

  # GET /admin/vendor_application_analytics/workload_distribution
  def workload_distribution
    @reviewer_workloads = calculate_detailed_reviewer_workloads
    @workload_balance = analyze_workload_balance
    @recommended_assignments = suggest_workload_rebalancing

    respond_to do |format|
      format.html
      format.json {
        render json: {
          workloads: @reviewer_workloads,
          balance: @workload_balance,
          recommendations: @recommended_assignments
        }
      }
    end
  end

  # GET /admin/vendor_application_analytics/real_time_stats
  def real_time_stats
    stats = {
      total_applications: VendorApplication.count,
      pending_review: VendorApplication.where(status: [ :submitted, :under_review ]).count,
      approved_today: VendorApplication.approved.where("reviewed_at >= ?", Date.current).count,
      rejected_today: VendorApplication.rejected.where("reviewed_at >= ?", Date.current).count,
      overdue_reviews: VendorApplication.joins(:festival)
                                       .where("vendor_applications.review_deadline < ?", Time.current)
                                       .where(status: [ :submitted, :under_review ]).count,
      average_score: calculate_average_application_score,
      busiest_reviewer: find_busiest_reviewer,
      latest_activity: get_latest_activity
    }

    render json: stats
  end

  private

  def parse_date_range
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current
    start_date..end_date
  end

  def generate_quick_stats
    {
      total_applications: VendorApplication.count,
      pending_applications: VendorApplication.where(status: [ :draft, :submitted, :under_review ]).count,
      approved_applications: VendorApplication.approved.count,
      rejected_applications: VendorApplication.rejected.count,
      overdue_reviews: VendorApplication.joins(:festival)
                                       .where("vendor_applications.review_deadline < ?", Time.current)
                                       .where(status: [ :submitted, :under_review ]).count,
      avg_processing_time: calculate_average_processing_time,
      approval_rate: calculate_overall_approval_rate
    }
  end

  def calculate_reviewer_workloads
    reviewers = User.where(role: [ :admin, :committee_member, :system_admin ])

    reviewers.map do |reviewer|
      current_workload = VendorApplication.where(assigned_reviewer: reviewer)
                                         .where(status: [ :submitted, :under_review ])
                                         .count

      total_reviewed = VendorApplication.joins(:application_reviews)
                                       .where(application_reviews: { reviewer: reviewer })
                                       .where("application_reviews.created_at >= ?", 30.days.ago)
                                       .distinct
                                       .count

      {
        reviewer: reviewer,
        name: reviewer.display_name,
        current_workload: current_workload,
        total_reviewed_30days: total_reviewed,
        capacity_utilization: [ (current_workload.to_f / 5 * 100).round(2), 100 ].min
      }
    end
  end

  def calculate_detailed_reviewer_workloads
    reviewers = User.where(role: [ :admin, :committee_member, :system_admin ])

    reviewers.map do |reviewer|
      applications = VendorApplication.joins(:application_reviews)
                                     .where(application_reviews: { reviewer: reviewer })
                                     .where("application_reviews.created_at >= ?", 30.days.ago)

      {
        reviewer_id: reviewer.id,
        name: reviewer.display_name,
        current_assigned: VendorApplication.where(assigned_reviewer: reviewer)
                                          .where(status: [ :submitted, :under_review ]).count,
        total_reviewed: applications.distinct.count,
        avg_review_time: calculate_reviewer_avg_time(reviewer),
        approval_rate: calculate_reviewer_approval_rate(reviewer),
        workload_score: calculate_workload_score(reviewer)
      }
    end
  end

  def analyze_workload_balance
    workloads = calculate_detailed_reviewer_workloads
    current_loads = workloads.map { |w| w[:current_assigned] }

    {
      max_workload: current_loads.max,
      min_workload: current_loads.min,
      avg_workload: (current_loads.sum.to_f / current_loads.length).round(2),
      workload_variance: calculate_variance(current_loads),
      balance_score: calculate_balance_score(current_loads)
    }
  end

  def suggest_workload_rebalancing
    workloads = calculate_detailed_reviewer_workloads
    suggestions = []

    overloaded_reviewers = workloads.select { |w| w[:current_assigned] > 7 }
    underloaded_reviewers = workloads.select { |w| w[:current_assigned] < 3 }

    overloaded_reviewers.each do |overloaded|
      underloaded_reviewers.each do |underloaded|
        suggestions << {
          from_reviewer: overloaded[:name],
          to_reviewer: underloaded[:name],
          recommended_transfers: [ (overloaded[:current_assigned] - 5), 3 ].min,
          reason: "負荷分散のため"
        }
      end
    end

    suggestions.first(5) # 上位5件の提案
  end

  def generate_trend_analysis
    last_30_days = VendorApplication.where("created_at >= ?", 30.days.ago)
    last_60_days = VendorApplication.where("created_at >= ?", 60.days.ago)

    {
      application_trend: {
        last_30_days: last_30_days.count,
        previous_30_days: last_60_days.where("created_at < ?", 30.days.ago).count,
        growth_rate: calculate_growth_rate(last_30_days.count, last_60_days.where("created_at < ?", 30.days.ago).count)
      },
      approval_trend: analyze_approval_trend,
      processing_time_trend: analyze_processing_time_trend
    }
  end

  def generate_capacity_forecast
    recent_applications = VendorApplication.where("created_at >= ?", 30.days.ago)
    daily_average = recent_applications.count.to_f / 30

    reviewers_count = User.where(role: [ :admin, :committee_member, :system_admin ]).count
    daily_capacity = reviewers_count * 2 # 1人1日2件処理と仮定

    {
      daily_average_applications: daily_average.round(2),
      daily_processing_capacity: daily_capacity,
      capacity_utilization: [ (daily_average / daily_capacity * 100).round(2), 100 ].min,
      forecast_30_days: {
        expected_applications: (daily_average * 30).round,
        processing_capacity: daily_capacity * 30,
        capacity_shortage: [ ((daily_average * 30) - (daily_capacity * 30)).round, 0 ].max
      }
    }
  end

  def prepare_export_data
    applications = VendorApplication.includes(:festival, :user, :application_reviews)
                                   .where(created_at: @date_range)

    {
      summary: VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:overview],
      applications: applications.map { |app| serialize_application_for_export(app) },
      reviewer_performance: VendorApplicationWorkflowService.generate_workflow_analytics(@date_range)[:reviewer_performance]
    }
  end

  def serialize_application(application)
    {
      id: application.id,
      business_name: application.business_name,
      business_type: application.business_type,
      status: application.status,
      status_text: application.status_text,
      priority: application.priority,
      priority_text: application.priority_text,
      festival: application.festival&.name,
      applicant: application.user&.display_name,
      created_at: application.created_at.iso8601,
      reviewed_at: application.reviewed_at&.iso8601,
      submission_deadline: application.submission_deadline&.iso8601,
      review_deadline: application.review_deadline&.iso8601
    }
  end

  def serialize_application_for_export(application)
    {
      id: application.id,
      business_name: application.business_name,
      business_type: application.business_type,
      description: application.description,
      status: application.status_text,
      priority: application.priority_text,
      festival: application.festival&.name,
      applicant: application.user&.display_name,
      applicant_email: application.user&.email,
      created_at: application.created_at.strftime("%Y-%m-%d %H:%M"),
      submitted_at: application.submitted_at&.strftime("%Y-%m-%d %H:%M"),
      reviewed_at: application.reviewed_at&.strftime("%Y-%m-%d %H:%M"),
      review_count: application.application_reviews.count,
      latest_reviewer: application.latest_review&.reviewer&.display_name,
      processing_time_days: application.reviewed? ? ((application.reviewed_at - application.created_at) / 1.day).round(2) : nil
    }
  end

  def calculate_average_processing_time
    reviewed_apps = VendorApplication.where.not(reviewed_at: nil)
    return 0 if reviewed_apps.empty?

    total_time = reviewed_apps.sum { |app| (app.reviewed_at - app.created_at) / 1.day }
    (total_time / reviewed_apps.count).round(2)
  end

  def calculate_overall_approval_rate
    total = VendorApplication.where(status: [ :approved, :rejected ]).count
    return 0 if total.zero?

    approved = VendorApplication.approved.count
    (approved.to_f / total * 100).round(2)
  end

  def calculate_reviewer_avg_time(reviewer)
    applications = VendorApplication.joins(:application_reviews)
                                   .where(application_reviews: { reviewer: reviewer })
                                   .where.not(reviewed_at: nil)
                                   .where("application_reviews.created_at >= ?", 30.days.ago)

    return 0 if applications.empty?

    total_time = applications.sum { |app| (app.reviewed_at - app.created_at) / 1.day }
    (total_time / applications.count).round(2)
  end

  def calculate_reviewer_approval_rate(reviewer)
    reviewed = VendorApplication.joins(:application_reviews)
                               .where(application_reviews: { reviewer: reviewer, action: [ :approved, :rejected ] })
                               .where("application_reviews.created_at >= ?", 30.days.ago)
                               .distinct

    return 0 if reviewed.empty?

    approved = reviewed.select { |app| app.approved? }.count
    (approved.to_f / reviewed.count * 100).round(2)
  end

  def calculate_workload_score(reviewer)
    current_load = VendorApplication.where(assigned_reviewer: reviewer)
                                   .where(status: [ :submitted, :under_review ]).count

    recent_activity = VendorApplication.joins(:application_reviews)
                                      .where(application_reviews: { reviewer: reviewer })
                                      .where("application_reviews.created_at >= ?", 7.days.ago)
                                      .distinct.count

    # 現在の負荷 * 2 + 最近の活動度で算出
    (current_load * 2 + recent_activity).round
  end

  def calculate_variance(values)
    return 0 if values.empty?
    mean = values.sum.to_f / values.length
    variance = values.sum { |v| (v - mean) ** 2 } / values.length
    variance.round(2)
  end

  def calculate_balance_score(workloads)
    return 100 if workloads.empty? || workloads.uniq.length == 1

    variance = calculate_variance(workloads)
    max_possible_variance = (workloads.max - workloads.min) ** 2 / 4

    return 100 if max_possible_variance.zero?

    balance_score = ((1 - (variance / max_possible_variance)) * 100).round(2)
    [ balance_score, 0 ].max
  end

  def calculate_growth_rate(current, previous)
    return 0 if previous.zero?
    (((current - previous).to_f / previous) * 100).round(2)
  end

  def analyze_approval_trend
    current_period = VendorApplication.where("reviewed_at >= ?", 30.days.ago)
                                     .where(status: [ :approved, :rejected ])

    previous_period = VendorApplication.where("reviewed_at >= ? AND reviewed_at < ?", 60.days.ago, 30.days.ago)
                                      .where(status: [ :approved, :rejected ])

    current_rate = current_period.approved.count.to_f / [ current_period.count, 1 ].max * 100
    previous_rate = previous_period.approved.count.to_f / [ previous_period.count, 1 ].max * 100

    {
      current_approval_rate: current_rate.round(2),
      previous_approval_rate: previous_rate.round(2),
      trend: current_rate - previous_rate
    }
  end

  def analyze_processing_time_trend
    current_period = VendorApplication.where("reviewed_at >= ?", 30.days.ago)
                                     .where.not(reviewed_at: nil)

    previous_period = VendorApplication.where("reviewed_at >= ? AND reviewed_at < ?", 60.days.ago, 30.days.ago)
                                      .where.not(reviewed_at: nil)

    current_avg = current_period.empty? ? 0 : current_period.sum { |app| (app.reviewed_at - app.created_at) / 1.day } / current_period.count
    previous_avg = previous_period.empty? ? 0 : previous_period.sum { |app| (app.reviewed_at - app.created_at) / 1.day } / previous_period.count

    {
      current_avg_days: current_avg.round(2),
      previous_avg_days: previous_avg.round(2),
      improvement: (previous_avg - current_avg).round(2)
    }
  end

  def calculate_average_application_score
    scores = VendorApplication.all.map do |app|
      VendorApplicationWorkflowService.new.calculate_application_score(app)
    end

    scores.empty? ? 0 : (scores.sum.to_f / scores.length).round(2)
  end

  def find_busiest_reviewer
    reviewer_counts = User.where(role: [ :admin, :committee_member, :system_admin ])
                         .left_joins(:application_reviews)
                         .where("application_reviews.created_at >= ?", 7.days.ago)
                         .group("users.id", "users.name")
                         .count("application_reviews.id")

    busiest = reviewer_counts.max_by { |reviewer, count| count }
    busiest ? { name: busiest[0][1], review_count: busiest[1] } : { name: "なし", review_count: 0 }
  end

  def get_latest_activity
    latest_review = ApplicationReview.includes(:reviewer, :vendor_application)
                                    .order(created_at: :desc)
                                    .first

    return { message: "最近の活動はありません" } unless latest_review

    {
      message: "#{latest_review.reviewer.display_name}が「#{latest_review.vendor_application.business_name}」を#{latest_review.action_text}",
      timestamp: latest_review.created_at.strftime("%Y-%m-%d %H:%M")
    }
  end

  def ensure_admin!
    unless current_user&.admin? || current_user&.committee_member? || current_user&.system_admin?
      redirect_to root_path, alert: "アクセス権限がありません。"
    end
  end
end
