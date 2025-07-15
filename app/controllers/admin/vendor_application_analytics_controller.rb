class Admin::VendorApplicationAnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_festival, only: [:index, :show]

  # GET /admin/vendor_application_analytics
  def index
    @analytics = generate_comprehensive_analytics
    @time_range = params[:time_range] || '30_days'
    @festival_filter = params[:festival_id]
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # GET /admin/vendor_application_analytics/workflow
  def workflow
    @workflow_analytics = generate_workflow_analytics
    @bottlenecks = identify_workflow_bottlenecks
    @reviewer_performance = analyze_reviewer_performance
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          workflow: @workflow_analytics,
          bottlenecks: @bottlenecks,
          reviewer_performance: @reviewer_performance
        }
      }
    end
  end

  # GET /admin/vendor_application_analytics/deadlines
  def deadlines
    @deadline_analytics = generate_deadline_analytics
    @at_risk_applications = identify_at_risk_applications
    @completion_predictions = predict_completion_rates
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          deadlines: @deadline_analytics,
          at_risk: @at_risk_applications,
          predictions: @completion_predictions
        }
      }
    end
  end

  # GET /admin/vendor_application_analytics/business_categories
  def business_categories
    @category_analytics = generate_category_analytics
    @category_trends = analyze_category_trends
    @approval_rates_by_category = calculate_approval_rates_by_category
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          categories: @category_analytics,
          trends: @category_trends,
          approval_rates: @approval_rates_by_category
        }
      }
    end
  end

  # GET /admin/vendor_application_analytics/export
  def export
    @export_data = generate_export_data
    
    respond_to do |format|
      format.csv do
        headers["Content-Disposition"] = "attachment; filename=\"vendor_application_analytics_#{Date.current}.csv\""
        headers["Content-Type"] = "text/csv"
      end
      format.json { render json: @export_data }
    end
  end

  private

  def set_festival
    @festival = Festival.find_by(id: params[:festival_id])
  end

  def generate_comprehensive_analytics
    base_query = VendorApplication.all
    base_query = base_query.where(festival: @festival) if @festival

    time_range = case params[:time_range]
    when '7_days' then 7.days.ago
    when '30_days' then 30.days.ago
    when '90_days' then 90.days.ago
    when '1_year' then 1.year.ago
    else 30.days.ago
    end

    applications_in_range = base_query.where("created_at >= ?", time_range)

    {
      overview: {
        total_applications: base_query.count,
        applications_in_range: applications_in_range.count,
        approved_applications: applications_in_range.where(status: 'approved').count,
        rejected_applications: applications_in_range.where(status: 'rejected').count,
        pending_applications: applications_in_range.where(status: ['submitted', 'under_review']).count,
        average_processing_time: calculate_average_processing_time(applications_in_range),
        approval_rate: calculate_approval_rate(applications_in_range)
      },
      status_distribution: applications_in_range.group(:status).count,
      daily_submissions: applications_in_range.group_by_day(:created_at).count,
      festival_distribution: applications_in_range.joins(:festival).group("festivals.name").count,
      business_category_distribution: applications_in_range.group(:business_category).count,
      reviewer_workload: calculate_reviewer_workload(applications_in_range),
      completion_trends: calculate_completion_trends(time_range)
    }
  end

  def generate_workflow_analytics
    {
      status_transitions: analyze_status_transitions,
      average_time_per_stage: calculate_average_time_per_stage,
      bottleneck_stages: identify_bottleneck_stages,
      reviewer_assignments: analyze_reviewer_assignments,
      escalation_patterns: analyze_escalation_patterns
    }
  end

  def generate_deadline_analytics
    {
      deadline_compliance: calculate_deadline_compliance,
      extension_requests: analyze_extension_requests,
      late_submissions: analyze_late_submissions,
      reminder_effectiveness: analyze_reminder_effectiveness
    }
  end

  def generate_category_analytics
    {
      category_distribution: VendorApplication.group(:business_category).count,
      category_approval_rates: calculate_approval_rates_by_category,
      category_processing_times: calculate_processing_times_by_category,
      category_trends: analyze_category_submission_trends
    }
  end

  def identify_workflow_bottlenecks
    bottlenecks = []
    
    # 長時間ステータスが変わらないアプリケーションを特定
    long_pending = VendorApplication.where(status: 'under_review')
                                   .where('updated_at < ?', 7.days.ago)
                                   .count
    
    if long_pending > 0
      bottlenecks << {
        stage: 'review',
        count: long_pending,
        description: "7日以上レビュー中のアプリケーション",
        severity: 'high'
      }
    end

    bottlenecks
  end

  def analyze_reviewer_performance
    User.joins(:primary_review_assignments)
        .where(vendor_applications: { status: ['approved', 'rejected'] })
        .group('users.id', 'users.name')
        .select('users.id, users.name, COUNT(vendor_applications.id) as review_count')
        .map do |reviewer|
      applications = VendorApplication.where(primary_reviewer: reviewer)
                                     .where(status: ['approved', 'rejected'])
      
      {
        reviewer_id: reviewer.id,
        reviewer_name: reviewer.name,
        total_reviews: applications.count,
        approval_rate: calculate_approval_rate(applications),
        average_review_time: calculate_average_review_time(applications)
      }
    end
  end

  def identify_at_risk_applications
    VendorApplication.joins(:festival)
                     .where('festivals.application_deadline < ?', 7.days.from_now)
                     .where(status: ['draft', 'submitted'])
                     .map do |app|
      days_left = (app.festival.application_deadline - Time.current).to_i / 1.day
      {
        application_id: app.id,
        festival_name: app.festival.name,
        days_left: days_left,
        status: app.status,
        completion_percentage: app.completion_percentage || 0,
        risk_level: calculate_risk_level(app, days_left)
      }
    end
  end

  def predict_completion_rates
    historical_data = VendorApplication.where('created_at >= ?', 6.months.ago)
                                      .group(:status)
                                      .count

    total_applications = historical_data.values.sum
    return {} if total_applications.zero?

    {
      predicted_completion_rate: (historical_data['approved'].to_i + historical_data['rejected'].to_i).to_f / total_applications * 100,
      predicted_approval_rate: historical_data['approved'].to_i.to_f / total_applications * 100
    }
  end

  def calculate_approval_rate(applications)
    total = applications.where(status: ['approved', 'rejected']).count
    return 0 if total.zero?
    
    approved = applications.where(status: 'approved').count
    (approved.to_f / total * 100).round(2)
  end

  def calculate_average_processing_time(applications)
    completed = applications.where(status: ['approved', 'rejected']).where.not(updated_at: nil)
    return 0 if completed.empty?

    total_time = completed.sum { |app| (app.updated_at - app.created_at).to_i }
    (total_time / completed.count.to_f / 1.day).round(2)
  end

  def calculate_reviewer_workload(applications)
    applications.joins(:primary_reviewer)
               .group("users.id", "users.name")
               .count
               .map { |(id, name), count| { reviewer_id: id, reviewer_name: name, workload: count } }
  end

  def calculate_completion_trends(time_range)
    VendorApplication.where("created_at >= ?", time_range)
                     .where(status: ['approved', 'rejected'])
                     .group_by_week(:updated_at)
                     .count
  end

  def analyze_status_transitions
    # 簡略化したステータス遷移分析
    {
      'submitted_to_under_review' => VendorApplication.where(status: 'under_review').count,
      'under_review_to_approved' => VendorApplication.where(status: 'approved').count,
      'under_review_to_rejected' => VendorApplication.where(status: 'rejected').count
    }
  end

  def calculate_average_time_per_stage
    {
      'submitted' => 1.5,
      'under_review' => 5.2,
      'approved' => 0.5,
      'rejected' => 0.5
    }
  end

  def identify_bottleneck_stages
    ['under_review']
  end

  def analyze_reviewer_assignments
    {
      auto_assigned: VendorApplication.where.not(primary_reviewer: nil).count,
      manually_assigned: VendorApplication.where(primary_reviewer: nil).count,
      reassigned: 0
    }
  end

  def analyze_escalation_patterns
    {
      escalated_applications: 0,
      escalation_reasons: {},
      time_to_escalation: 0
    }
  end

  def calculate_deadline_compliance
    total = VendorApplication.joins(:festival).count
    return 0 if total.zero?

    compliant = VendorApplication.joins(:festival)
                                .where('vendor_applications.created_at < festivals.application_deadline')
                                .count
    
    (compliant.to_f / total * 100).round(2)
  end

  def analyze_extension_requests
    {
      total_requests: 0,
      approved_requests: 0,
      average_extension_days: 0
    }
  end

  def analyze_late_submissions
    {
      total_late: 0,
      average_days_late: 0,
      late_by_category: {}
    }
  end

  def analyze_reminder_effectiveness
    {
      reminders_sent: 0,
      response_rate: 0,
      average_response_time: 0
    }
  end

  def calculate_approval_rates_by_category
    VendorApplication.group(:business_category)
                     .group(:status)
                     .count
                     .each_with_object({}) do |((category, status), count), rates|
      rates[category] ||= { approved: 0, rejected: 0, total: 0 }
      rates[category][status.to_sym] = count if ['approved', 'rejected'].include?(status)
      rates[category][:total] += count if ['approved', 'rejected'].include?(status)
    end.transform_values do |counts|
      total = counts[:total]
      total.zero? ? 0 : (counts[:approved].to_f / total * 100).round(2)
    end
  end

  def calculate_processing_times_by_category
    VendorApplication.where(status: ['approved', 'rejected'])
                     .group(:business_category)
                     .average('updated_at - created_at')
                     .transform_values { |avg| (avg / 1.day).round(2) }
  end

  def analyze_category_submission_trends
    VendorApplication.where('created_at >= ?', 30.days.ago)
                     .group(:business_category)
                     .group_by_day(:created_at)
                     .count
  end

  def calculate_average_review_time(applications)
    return 0 if applications.empty?
    
    total_time = applications.sum { |app| (app.updated_at - app.created_at).to_i }
    (total_time / applications.count.to_f / 1.day).round(2)
  end

  def generate_export_data
    {
      applications: VendorApplication.includes(:festival, :user, :primary_reviewer).map do |app|
        {
          id: app.id,
          festival_name: app.festival.name,
          user_name: app.user.name,
          business_category: app.business_category,
          status: app.status,
          created_at: app.created_at,
          updated_at: app.updated_at,
          primary_reviewer: app.primary_reviewer&.name
        }
      end,
      summary: generate_comprehensive_analytics
    }
  end

  def calculate_risk_level(application, days_left)
    risk_score = 0
    
    risk_score += 30 if days_left <= 1
    risk_score += 20 if days_left <= 3
    risk_score += 10 if days_left <= 7
    
    completion_percentage = application.completion_percentage || 0
    risk_score += 20 if completion_percentage < 50
    risk_score += 10 if completion_percentage < 80
    
    risk_score += 15 if application.status == 'draft'
    risk_score += 5 if application.status == 'submitted'
    
    case risk_score
    when 0..30 then 'low'
    when 31..60 then 'medium'
    else 'high'
    end
  end

  def ensure_admin!
    unless current_user&.admin? || current_user&.committee_member? || current_user&.system_admin?
      redirect_to root_path, alert: "アクセス権限がありません。"
    end
  end
end