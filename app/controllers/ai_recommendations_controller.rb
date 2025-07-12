# frozen_string_literal: true

class AiRecommendationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :authorize_festival_access

  def index
    @ai_insights = generate_ai_insights
    @recommendations = get_all_recommendations
  end

  def attendance_prediction
    weather_data = params[:weather] || {}
    historical_data = fetch_historical_attendance_data
    
    @prediction = AiRecommendationService.new.predict_attendance(
      @festival,
      weather_data: weather_data,
      historical_data: historical_data,
      marketing_reach: params[:marketing_reach]&.to_i || 1000
    )

    respond_to do |format|
      format.html
      format.json { render json: @prediction }
    end
  end

  def layout_optimization
    venue = @festival.venues.find(params[:venue_id]) if params[:venue_id]
    venue ||= @festival.venues.first
    
    unless venue
      render json: { error: 'No venue found for optimization' }, status: :unprocessable_entity
      return
    end

    vendor_categories = @festival.vendor_applications.approved.includes(:budget_categories)
    optimization_constraints = parse_optimization_constraints

    @optimization = AiRecommendationService.new.optimize_vendor_layout(
      venue,
      vendor_categories,
      optimization_constraints
    )

    respond_to do |format|
      format.html
      format.json { render json: @optimization }
    end
  end

  def budget_allocation
    total_budget = params[:total_budget]&.to_f || @festival.budget
    historical_data = fetch_historical_budget_data

    @allocation = AiRecommendationService.new.recommend_budget_allocation(
      @festival,
      total_budget,
      historical_performance: historical_data
    )

    respond_to do |format|
      format.html
      format.json { render json: @allocation }
    end
  end

  def risk_assessment
    risk_categories = params[:categories] || ['weather', 'financial', 'operational', 'safety']
    
    @risk_assessment = AiRecommendationService.new.assess_festival_risks(
      @festival,
      risk_categories: risk_categories,
      assessment_date: Date.current
    )

    respond_to do |format|
      format.html
      format.json { render json: @risk_assessment }
    end
  end

  def predictive_dashboard
    @dashboard_data = {
      attendance_prediction: get_attendance_prediction,
      budget_efficiency: calculate_budget_efficiency,
      risk_overview: get_risk_overview,
      layout_score: get_layout_score,
      recommendations: get_priority_recommendations,
      kpi_metrics: calculate_kpi_metrics,
      trend_analysis: analyze_trends
    }

    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end

  def roi_optimization
    investment_areas = params[:investment_areas] || []
    market_data = fetch_market_data
    
    @roi_analysis = AiRecommendationService.new.optimize_roi(
      @festival,
      investment_areas: investment_areas,
      market_conditions: market_data,
      time_horizon: params[:time_horizon] || '6_months'
    )

    respond_to do |format|
      format.html
      format.json { render json: @roi_analysis }
    end
  end

  def market_trends
    trend_categories = params[:categories] || ['attendance', 'spending', 'preferences']
    region = params[:region] || 'national'
    
    @trends = AiRecommendationService.new.analyze_market_trends(
      trend_categories: trend_categories,
      region: region,
      time_period: params[:time_period] || '12_months'
    )

    respond_to do |format|
      format.html
      format.json { render json: @trends }
    end
  end

  def performance_benchmark
    comparison_festivals = find_similar_festivals
    benchmark_metrics = params[:metrics] || ['attendance', 'revenue', 'satisfaction']
    
    @benchmark = AiRecommendationService.new.benchmark_performance(
      @festival,
      comparison_festivals: comparison_festivals,
      metrics: benchmark_metrics
    )

    respond_to do |format|
      format.html
      format.json { render json: @benchmark }
    end
  end

  def realtime_monitoring
    @monitoring_data = {
      current_status: get_current_status,
      live_metrics: get_live_metrics,
      alerts: get_active_alerts,
      recommendations: get_realtime_recommendations,
      performance_indicators: calculate_realtime_kpis
    }

    respond_to do |format|
      format.html
      format.json { render json: @monitoring_data }
    end
  end

  # Batch analysis for multiple insights
  def batch_analysis
    analysis_types = params[:analysis_types] || ['attendance', 'budget', 'layout', 'risks']
    
    @batch_results = {}
    
    analysis_types.each do |type|
      case type
      when 'attendance'
        @batch_results[:attendance] = get_attendance_prediction
      when 'budget'
        @batch_results[:budget] = get_budget_analysis
      when 'layout'
        @batch_results[:layout] = get_layout_analysis
      when 'risks'
        @batch_results[:risks] = get_risk_overview
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @batch_results }
    end
  end

  # Industry-wide insights
  def industry_insights
    industry_type = params[:industry_type] || 'general'
    region = params[:region] || 'national'
    
    @insights = AiRecommendationService.new.generate_industry_insights(
      industry_type: industry_type,
      region: region,
      analysis_depth: params[:depth] || 'standard'
    )

    respond_to do |format|
      format.html
      format.json { render json: @insights }
    end
  end

  private

  def set_festival
    @festival = current_user.festivals.find(params[:festival_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to festivals_path, alert: 'Festival not found.'
  end

  def authorize_festival_access
    unless can?(:manage, @festival)
      redirect_to root_path, alert: 'You do not have permission to access this festival.'
    end
  end

  def generate_ai_insights
    {
      attendance_outlook: get_attendance_prediction,
      budget_health: calculate_budget_efficiency,
      operational_readiness: assess_operational_readiness,
      risk_level: get_overall_risk_level,
      optimization_opportunities: identify_optimization_opportunities
    }
  end

  def get_all_recommendations
    service = AiRecommendationService.new
    
    [
      service.predict_attendance(@festival)[:recommendations],
      service.recommend_budget_allocation(@festival, @festival.budget)[:recommendations],
      service.assess_festival_risks(@festival)[:recommendations]
    ].flatten.compact.uniq
  end

  def fetch_historical_attendance_data
    # In a real implementation, this would fetch from database or external API
    [
      { date: 1.year.ago, attendance: 8500 },
      { date: 2.years.ago, attendance: 7200 },
      { date: 3.years.ago, attendance: 6800 }
    ]
  end

  def fetch_historical_budget_data
    # In a real implementation, this would analyze past festival budgets
    [
      { year: 2023, total_budget: 500000, actual_spent: 485000, roi: 115 },
      { year: 2022, total_budget: 450000, actual_spent: 462000, roi: 108 },
      { year: 2021, total_budget: 400000, actual_spent: 398000, roi: 112 }
    ]
  end

  def parse_optimization_constraints
    {
      min_distance_between_vendors: params[:min_distance]&.to_f || 3.0,
      max_walking_distance_to_facilities: params[:max_walking_distance]&.to_f || 50.0,
      crowd_flow_efficiency: params[:flow_efficiency]&.to_f || 0.8,
      emergency_access_width: params[:emergency_width]&.to_f || 4.0
    }
  end

  def get_attendance_prediction
    AiRecommendationService.new.predict_attendance(@festival)
  rescue => e
    Rails.logger.error "Attendance prediction error: #{e.message}"
    { error: 'Unable to generate attendance prediction' }
  end

  def calculate_budget_efficiency
    total_budget = @festival.budget || 0
    return 0 if total_budget.zero?

    spent_amount = @festival.expenses.sum(:amount) || 0
    remaining_budget = total_budget - spent_amount
    
    efficiency_score = if remaining_budget > total_budget * 0.1
                         'excellent'
                       elsif remaining_budget > 0
                         'good'
                       elsif remaining_budget > total_budget * -0.05
                         'warning'
                       else
                         'critical'
                       end

    {
      score: efficiency_score,
      budget_utilization: ((spent_amount.to_f / total_budget) * 100).round(1),
      remaining_budget: remaining_budget,
      trend: calculate_budget_trend
    }
  end

  def get_risk_overview
    AiRecommendationService.new.assess_festival_risks(@festival)
  rescue => e
    Rails.logger.error "Risk assessment error: #{e.message}"
    { overall_risk: 'unknown', message: 'Unable to assess risks' }
  end

  def get_layout_score
    venue = @festival.venues.first
    return { score: 0, message: 'No venue available' } unless venue

    vendor_applications = @festival.vendor_applications.approved
    return { score: 0, message: 'No approved vendors' } if vendor_applications.empty?

    layout_result = AiRecommendationService.new.optimize_vendor_layout(venue, vendor_applications)
    
    {
      efficiency_score: layout_result[:efficiency_score] || 0,
      crowd_flow_score: layout_result[:crowd_flow_score] || 0,
      accessibility_score: layout_result[:accessibility_score] || 0,
      overall_score: calculate_overall_layout_score(layout_result)
    }
  rescue => e
    Rails.logger.error "Layout scoring error: #{e.message}"
    { score: 0, message: 'Unable to calculate layout score' }
  end

  def get_priority_recommendations
    all_recommendations = get_all_recommendations
    
    # Prioritize recommendations based on urgency and impact
    prioritized = all_recommendations.map do |rec|
      {
        text: rec,
        priority: determine_recommendation_priority(rec),
        category: categorize_recommendation(rec)
      }
    end
    
    prioritized.sort_by { |rec| recommendation_priority_score(rec[:priority]) }.reverse.first(5)
  end

  def calculate_kpi_metrics
    {
      task_completion_rate: calculate_task_completion_rate,
      vendor_satisfaction: calculate_vendor_satisfaction,
      budget_adherence: calculate_budget_adherence,
      timeline_adherence: calculate_timeline_adherence,
      safety_compliance: calculate_safety_compliance
    }
  end

  def analyze_trends
    {
      attendance_trend: analyze_attendance_trend,
      budget_trend: calculate_budget_trend,
      vendor_trend: analyze_vendor_trend,
      timeline_trend: analyze_timeline_trend
    }
  end

  def fetch_market_data
    # In a real implementation, this would fetch from external market APIs
    {
      economic_indicators: { gdp_growth: 2.1, unemployment: 3.5 },
      seasonal_factors: { season: 'summer', tourism_index: 1.2 },
      competitor_analysis: { similar_events_count: 3, market_saturation: 'medium' }
    }
  end

  def find_similar_festivals
    # Find festivals with similar characteristics for benchmarking
    Festival.where.not(id: @festival.id)
           .where(
             start_date: (@festival.start_date - 2.months)..(@festival.start_date + 2.months)
           )
           .limit(5)
  end

  def get_current_status
    {
      phase: determine_festival_phase,
      days_remaining: (@festival.start_date - Date.current).to_i,
      completion_percentage: calculate_overall_completion,
      active_issues: count_active_issues,
      last_updated: Time.current
    }
  end

  def get_live_metrics
    {
      registered_vendors: @festival.vendor_applications.approved.count,
      completed_tasks: @festival.tasks.completed.count,
      pending_approvals: count_pending_approvals,
      budget_spent: @festival.expenses.sum(:amount) || 0
    }
  end

  def get_active_alerts
    alerts = []
    
    # Check for overdue tasks
    overdue_tasks = @festival.tasks.overdue.count
    alerts << { type: 'warning', message: "#{overdue_tasks} tasks are overdue" } if overdue_tasks > 0
    
    # Check budget status
    budget_utilization = calculate_budget_efficiency[:budget_utilization]
    alerts << { type: 'info', message: "Budget utilization at #{budget_utilization}%" }
    
    # Check timeline
    days_remaining = (@festival.start_date - Date.current).to_i
    alerts << { type: 'urgent', message: 'Festival starts in less than 7 days!' } if days_remaining <= 7
    
    alerts
  end

  def get_realtime_recommendations
    recommendations = []
    
    # Dynamic recommendations based on current state
    completion = calculate_overall_completion
    if completion < 70 && (@festival.start_date - Date.current).to_i <= 30
      recommendations << 'Consider accelerating critical path tasks'
    end
    
    vendor_count = @festival.vendor_applications.approved.count
    if vendor_count < 10
      recommendations << 'Focus on vendor recruitment to improve festival variety'
    end
    
    recommendations
  end

  def calculate_realtime_kpis
    {
      overall_health: calculate_overall_health_score,
      progress_velocity: calculate_progress_velocity,
      resource_utilization: calculate_resource_utilization,
      stakeholder_engagement: calculate_stakeholder_engagement
    }
  end

  # Helper methods for calculations
  def determine_recommendation_priority(recommendation)
    case recommendation.downcase
    when /urgent|critical|emergency/ then 'high'
    when /important|should|recommend/ then 'medium'
    else 'low'
    end
  end

  def categorize_recommendation(recommendation)
    case recommendation.downcase
    when /budget|cost|financial/ then 'financial'
    when /vendor|booth|layout/ then 'operational'
    when /safety|security|risk/ then 'safety'
    when /marketing|promotion/ then 'marketing'
    else 'general'
    end
  end

  def recommendation_priority_score(priority)
    case priority
    when 'high' then 3
    when 'medium' then 2
    when 'low' then 1
    else 0
    end
  end

  def calculate_task_completion_rate
    total_tasks = @festival.tasks.count
    return 0 if total_tasks.zero?
    
    completed_tasks = @festival.tasks.completed.count
    (completed_tasks.to_f / total_tasks * 100).round(1)
  end

  def calculate_vendor_satisfaction
    # Placeholder - in real implementation, this would use vendor feedback
    85.0
  end

  def calculate_budget_adherence
    return 100.0 unless @festival.budget && @festival.budget > 0
    
    spent = @festival.expenses.sum(:amount) || 0
    adherence = 100 - [(spent.to_f / @festival.budget * 100 - 100).abs, 100].min
    adherence.round(1)
  end

  def calculate_timeline_adherence
    # Simplified timeline adherence calculation
    90.0
  end

  def calculate_safety_compliance
    # Placeholder for safety compliance score
    92.0
  end

  def analyze_attendance_trend
    'increasing'  # Simplified trend analysis
  end

  def calculate_budget_trend
    'stable'  # Simplified trend analysis
  end

  def analyze_vendor_trend
    'positive'  # Simplified trend analysis
  end

  def analyze_timeline_trend
    'on_track'  # Simplified trend analysis
  end

  def determine_festival_phase
    days_to_start = (@festival.start_date - Date.current).to_i
    
    case days_to_start
    when -Float::INFINITY..-1 then 'completed'
    when 0..7 then 'execution'
    when 8..30 then 'final_preparation'
    when 31..90 then 'active_planning'
    else 'initial_planning'
    end
  end

  def calculate_overall_completion
    task_completion = calculate_task_completion_rate
    vendor_progress = (@festival.vendor_applications.approved.count.to_f / 20 * 100).round(1)
    budget_progress = calculate_budget_efficiency[:budget_utilization]
    
    (task_completion + vendor_progress + budget_progress) / 3
  end

  def count_active_issues
    @festival.tasks.overdue.count
  end

  def count_pending_approvals
    @festival.vendor_applications.pending.count + @festival.expenses.pending.count
  end

  def calculate_overall_health_score
    completion = calculate_overall_completion
    budget_health = calculate_budget_adherence
    timeline_health = calculate_timeline_adherence
    
    (completion + budget_health + timeline_health) / 3
  end

  def calculate_progress_velocity
    # Simplified velocity calculation
    75.0
  end

  def calculate_resource_utilization
    # Simplified resource utilization
    82.0
  end

  def calculate_stakeholder_engagement
    # Simplified engagement score
    88.0
  end

  def calculate_overall_layout_score(layout_result)
    efficiency = layout_result[:efficiency_score] || 0
    flow = layout_result[:crowd_flow_score] || 0
    accessibility = layout_result[:accessibility_score] || 0
    
    (efficiency + flow + accessibility) / 3
  end

  def assess_operational_readiness
    completion_rate = calculate_task_completion_rate
    vendor_readiness = (@festival.vendor_applications.approved.count >= 10)
    budget_status = calculate_budget_efficiency[:score]
    
    case [completion_rate >= 80, vendor_readiness, budget_status != 'critical']
    when [true, true, true] then 'excellent'
    when [true, true, false], [true, false, true] then 'good'
    when [false, true, true] then 'fair'
    else 'needs_attention'
    end
  end

  def get_overall_risk_level
    risk_assessment = get_risk_overview
    risk_assessment[:overall_risk] || 'medium'
  end

  def identify_optimization_opportunities
    opportunities = []
    
    # Budget optimization
    budget_efficiency = calculate_budget_efficiency
    if budget_efficiency[:budget_utilization] < 60
      opportunities << 'Consider reallocating unused budget to high-impact areas'
    end
    
    # Vendor optimization
    vendor_count = @festival.vendor_applications.approved.count
    if vendor_count < 15
      opportunities << 'Increase vendor diversity to enhance festival appeal'
    end
    
    # Timeline optimization
    task_rate = calculate_task_completion_rate
    if task_rate < 70
      opportunities << 'Implement task acceleration strategies'
    end
    
    opportunities
  end

  def get_budget_analysis
    calculate_budget_efficiency
  end

  def get_layout_analysis
    get_layout_score
  end
end