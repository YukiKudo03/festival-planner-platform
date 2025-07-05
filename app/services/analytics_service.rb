class AnalyticsService
  def initialize(festival = nil, date_range = nil)
    @festival = festival
    @date_range = date_range || default_date_range
  end

  # メインダッシュボード用の包括的な分析データ
  def dashboard_data
    Rails.cache.fetch("analytics_dashboard_#{@festival&.id}", expires_in: 30.minutes) do
      {
        overview: overview_metrics,
        budget_analytics: budget_analytics,
        task_analytics: task_analytics,
        vendor_analytics: vendor_analytics,
        venue_analytics: venue_analytics,
        communication_analytics: communication_analytics,
        trends: trend_analysis,
        recommendations: generate_recommendations
      }
    end
  end

  # 概要メトリクス
  def overview_metrics
    return {} unless @festival
    
    {
      total_budget: @festival.budget || 0,
      total_expenses: @festival.total_expenses,
      total_revenue: @festival.total_revenues,
      budget_utilization: @festival.budget_utilization_rate,
      vendor_count: @festival.vendor_applications.count,
      task_completion_rate: @festival.completion_rate,
      days_until_event: days_until_event
    }
  end

  # 予算・財務分析
  def budget_analytics
    return {} unless @festival

    {
      total_budget: @festival.budget || 0,
      total_expenses: @festival.total_expenses,
      total_revenue: @festival.total_revenues,
      net_profit: @festival.net_profit,
      category_breakdown: expense_breakdown_by_category,
      monthly_trends: monthly_cash_flow,
      budget_health: budget_health_assessment
    }
  end

  # タスク・プロジェクト分析
  def task_analytics
    return {} unless @festival

    tasks = @festival.tasks
    total_tasks = tasks.count
    completed_tasks = tasks.completed.count
    pending_tasks = tasks.pending.count
    overdue_tasks = tasks.where('due_date < ? AND status != ?', Date.current, Task.statuses[:completed]).count
    
    {
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      pending_tasks: pending_tasks,
      overdue_tasks: overdue_tasks,
      completion_rate: total_tasks > 0 ? (completed_tasks.to_f / total_tasks * 100).round(2) : 0.0,
      average_completion_time: calculate_average_completion_time(tasks),
      tasks_by_priority: {
        high: tasks.where(priority: :high).count,
        medium: tasks.where(priority: :medium).count,
        low: tasks.where(priority: :low).count
      },
      upcoming_deadlines: tasks.where('due_date > ? AND due_date < ?', Date.current, 7.days.from_now).limit(5).pluck(:title, :due_date)
    }
  end

  # 出店者・ベンダー分析
  def vendor_analytics
    return {} unless @festival

    applications = @festival.vendor_applications
    total_applications = applications.count
    approved_applications = applications.approved.count
    pending_applications = applications.under_review.count
    rejected_applications = applications.rejected.count
    
    {
      total_applications: total_applications,
      approved_applications: approved_applications,
      pending_applications: pending_applications,
      rejected_applications: rejected_applications,
      approval_rate: total_applications > 0 ? (approved_applications.to_f / total_applications * 100).round(2) : 0.0,
      revenue_by_category: revenue_breakdown_by_category,
      top_vendors: get_top_vendors
    }
  end

  # 会場・レイアウト分析
  def venue_analytics
    return {} unless @festival

    venues = @festival.venues
    total_capacity = venues.sum(:capacity)
    allocated_spaces = @festival.booths.count
    
    {
      total_capacity: total_capacity,
      allocated_spaces: allocated_spaces,
      utilization_rate: total_capacity > 0 ? (allocated_spaces.to_f / total_capacity * 100).round(2) : 0.0,
      space_breakdown: venues.group(:facility_type).sum(:capacity),
      layout_efficiency: calculate_layout_efficiency
    }
  end

  # コミュニケーション分析
  def communication_analytics
    return {} unless @festival

    forum_posts = @festival.forums.joins(:forum_threads).joins(:forum_posts).count
    chat_messages = @festival.chat_rooms.joins(:chat_messages).count
    active_discussions = @festival.forums.joins(:forum_threads).where('forum_threads.updated_at > ?', 7.days.ago).count
    
    {
      total_messages: forum_posts + chat_messages,
      active_discussions: active_discussions,
      participant_engagement: {
        daily_active_users: calculate_daily_active_users,
        messages_per_user: calculate_messages_per_user,
        engagement_score: calculate_engagement_score
      },
      message_trends: calculate_message_trends,
      popular_topics: get_popular_topics
    }
  end

  # トレンド分析
  def trend_analysis
    return {} unless @festival
    
    {
      budget_trends: budget_trend_data,
      task_completion_trends: task_completion_trend_data,
      vendor_application_trends: vendor_application_trend_data,
      communication_trends: communication_trend_data,
      predictions: {
        budget_forecast: forecast_budget_completion,
        completion_forecast: forecast_task_completion,
        risk_assessment: assess_project_risks
      }
    }
  end

  # パフォーマンス指標
  def performance_indicators
    {
      kpis: key_performance_indicators,
      sla_metrics: service_level_metrics,
      user_satisfaction: user_satisfaction_scores,
      system_performance: system_performance_metrics,
      business_metrics: business_performance_metrics,
      operational_efficiency: operational_efficiency_metrics
    }
  end

  # 時系列データ生成（グラフ用）
  def time_series_data(metric, period = 'daily')
    case metric
    when 'budget_utilization'
      generate_budget_time_series(period)
    when 'task_completion'
      generate_task_completion_time_series(period)
    when 'vendor_applications'
      generate_vendor_application_time_series(period)
    when 'user_activity'
      generate_user_activity_time_series(period)
    when 'communication_volume'
      generate_communication_time_series(period)
    else
      {}
    end
  end

  # 予測分析
  def forecast_analysis(metric, periods = 30)
    case metric
    when 'budget'
      forecast_budget_trends(periods)
    when 'task_completion'
      forecast_task_completion(periods)
    when 'vendor_applications'
      forecast_vendor_applications(periods)
    when 'user_growth'
      forecast_user_growth(periods)
    else
      {}
    end
  end

  # 比較分析
  def comparative_analysis(comparison_type = 'previous_period')
    case comparison_type
    when 'previous_period'
      previous_period_comparison
    when 'same_period_last_year'
      year_over_year_comparison
    when 'industry_average'
      industry_benchmark_comparison
    when 'best_performing'
      best_performing_comparison
    else
      {}
    end
  end

  # レコメンデーション
  def generate_recommendations
    return [] unless @festival
    
    recommendations = []
    
    # Budget recommendations
    utilization_rate = @festival.budget_utilization_rate
    if utilization_rate > 90
      recommendations << {
        type: 'budget',
        priority: 'high',
        message: 'Budget utilization is over 90%. Consider reviewing expenses.',
        action: 'Review and optimize budget allocation'
      }
    end
    
    # Task recommendations
    if @festival.completion_rate < 70
      recommendations << {
        type: 'task',
        priority: 'medium',
        message: 'Task completion rate is below 70%. Focus on task management.',
        action: 'Prioritize pending tasks and set clear deadlines'
      }
    end
    
    # Vendor recommendations
    if @festival.vendor_applications.under_review.count > 5
      recommendations << {
        type: 'vendor',
        priority: 'medium',
        message: 'Multiple vendor applications are pending review.',
        action: 'Review pending vendor applications promptly'
      }
    end
    
    recommendations
  end
  
  # Export functionality
  def export_data(format = :json)
    data = {
      overview: overview_metrics,
      budget_analytics: budget_analytics,
      task_analytics: task_analytics,
      vendor_analytics: vendor_analytics
    }
    
    case format
    when :json
      {
        format: 'json',
        data: data,
        generated_at: Time.current
      }
    when :csv
      {
        format: 'csv',
        data: convert_to_csv(data),
        generated_at: Time.current
      }
    else
      { error: 'Unsupported format' }
    end
  end
  
  # Cache invalidation
  def invalidate_cache
    Rails.cache.delete("analytics_dashboard_#{@festival&.id}")
  end

  private

  def default_date_range
    if @festival
      @festival.start_date..@festival.end_date
    else
      30.days.ago..Date.current
    end
  end

  # 基本メトリクス計算
  def total_festivals_count
    scope = Festival.all
    scope = scope.where(created_at: @date_range) if @date_range
    scope.count
  end

  def active_festivals_count
    Festival.where(status: :active).count
  end

  def total_vendors_count
    scope = User.joins(:vendor_applications)
    scope = scope.where(vendor_applications: { created_at: @date_range }) if @date_range
    scope.distinct.count
  end

  def total_revenue_amount
    scope = Revenue.confirmed
    scope = scope.where(created_at: @date_range) if @date_range
    scope = scope.where(festival: @festival) if @festival
    scope.sum(:amount)
  end

  def overall_completion_rate
    scope = Task.all
    scope = scope.where(festival: @festival) if @festival
    total_tasks = scope.count
    return 0 if total_tasks.zero?
    
    completed_tasks = scope.where(status: :completed).count
    (completed_tasks.to_f / total_tasks * 100).round(2)
  end

  def user_activity_metrics
    {
      daily_active_users: calculate_daily_active_users,
      weekly_active_users: calculate_weekly_active_users,
      monthly_active_users: calculate_monthly_active_users,
      user_retention_rate: calculate_user_retention_rate,
      new_user_growth: calculate_new_user_growth
    }
  end

  def growth_metrics
    {
      festival_growth: calculate_festival_growth,
      vendor_growth: calculate_vendor_growth,
      revenue_growth: calculate_revenue_growth,
      user_growth: calculate_user_growth_rate
    }
  end

  # 予算分析の詳細実装
  def budget_utilization_rate
    return 0 unless @festival

    total_budget = @festival.budget
    return 0 if total_budget.zero?

    spent_amount = @festival.expenses.approved.sum(:amount)
    (spent_amount / total_budget * 100).round(2)
  end

  def expense_breakdown_by_category
    return [] unless @festival

    @festival.budget_categories.includes(:expenses).map do |category|
      spent = category.expenses.approved.sum(:amount)
      budget = category.budget_limit || 0
      percentage = budget > 0 ? (spent / budget * 100).round(2) : 0
      
      {
        name: category.name,
        budget: budget,
        spent: spent,
        percentage: percentage
      }
    end
  end

  def revenue_breakdown_by_source
    return {} unless @festival

    @festival.revenues.confirmed.group(:source).sum(:amount)
  end

  def monthly_cash_flow
    return [] unless @festival

    # Get data for last 12 months
    start_date = 12.months.ago.beginning_of_month
    end_date = Date.current.end_of_month
    
    revenues_by_month = @festival.revenues.confirmed
                                .where(created_at: start_date..end_date)
                                .group("DATE_TRUNC('month', created_at)")
                                .sum(:amount)
    
    expenses_by_month = @festival.expenses.approved
                                .where(created_at: start_date..end_date)
                                .group("DATE_TRUNC('month', created_at)")
                                .sum(:amount)

    # Generate array for last 12 months
    (0..11).map do |i|
      month = i.months.ago.beginning_of_month
      revenue = revenues_by_month[month] || 0
      expense = expenses_by_month[month] || 0
      
      {
        month: month.strftime('%Y-%m'),
        revenue: revenue,
        expense: expense,
        net: revenue - expense
      }
    end.reverse
  end

  def budget_vs_actual_comparison
    return {} unless @festival

    @festival.budget_categories.map do |category|
      {
        category: category.name,
        budgeted: category.budget_limit,
        actual: category.total_expenses,
        variance: category.budget_limit - category.total_expenses,
        variance_percentage: category.budget_variance_percentage
      }
    end
  end

  # タスク分析の詳細実装
  def task_completion_trends
    return {} unless @festival

    # Get task completion data for last 30 days
    @festival.tasks.where(updated_at: 30.days.ago..Time.current)
                   .group(:status)
                   .count
  end

  def task_efficiency_metrics
    return {} unless @festival

    tasks = @festival.tasks.completed
    return {} if tasks.empty?

    average_completion_time = tasks.average('EXTRACT(epoch FROM (updated_at - created_at)) / 86400')
    
    {
      average_completion_days: average_completion_time&.round(2) || 0,
      on_time_completion_rate: calculate_on_time_completion_rate(tasks),
      productivity_score: calculate_productivity_score(tasks)
    }
  end

  def identify_bottlenecks
    return {} unless @festival

    overdue_tasks = @festival.tasks.where('due_date < ? AND status != ?', Date.current, Task.statuses[:completed])
    
    {
      overdue_count: overdue_tasks.count,
      categories_with_delays: overdue_tasks.group(:category).count,
      average_delay_days: calculate_average_delay_days(overdue_tasks)
    }
  end

  # 出店者分析の詳細実装
  def vendor_application_trends
    return {} unless @festival

    @festival.vendor_applications
             .where(created_at: 12.weeks.ago..Time.current)
             .group(:status)
             .count
  end

  def vendor_approval_rates
    return {} unless @festival

    applications = @festival.vendor_applications
    total = applications.count
    return {} if total.zero?

    {
      total_applications: total,
      approved: applications.approved.count,
      rejected: applications.rejected.count,
      pending: applications.under_review.count,
      approval_rate: (applications.approved.count.to_f / total * 100).round(2)
    }
  end

  # ヘルパーメソッド
  def calculate_daily_active_users
    User.joins(:received_notifications)
        .where(received_notifications: { created_at: 1.day.ago..Time.current })
        .distinct
        .count
  end

  def calculate_weekly_active_users
    User.joins(:received_notifications)
        .where(received_notifications: { created_at: 1.week.ago..Time.current })
        .distinct
        .count
  end

  def calculate_monthly_active_users
    User.joins(:received_notifications)
        .where(received_notifications: { created_at: 1.month.ago..Time.current })
        .distinct
        .count
  end

  # 追加の分析メソッドは必要に応じて実装
  def calculate_user_retention_rate
    # Implementation for user retention calculation
    0.0
  end

  def calculate_new_user_growth
    # Implementation for new user growth calculation
    0.0
  end

  def calculate_festival_growth
    # Implementation for festival growth calculation
    0.0
  end

  def calculate_vendor_growth
    # Implementation for vendor growth calculation
    0.0
  end

  def calculate_revenue_growth
    # Implementation for revenue growth calculation
    0.0
  end

  def calculate_user_growth_rate
    # Implementation for user growth rate calculation
    0.0
  end

  # Helper methods for analytics
  def days_until_event
    return 0 unless @festival&.start_date
    (@festival.start_date.to_date - Date.current).to_i
  end
  
  def budget_health_assessment
    utilization = @festival.budget_utilization_rate
    
    status = case utilization
    when 0..60 then 'excellent'
    when 61..80 then 'good' 
    when 81..95 then 'warning'
    else 'critical'
    end
    
    {
      status: status,
      score: (100 - utilization).round(2),
      warnings: utilization > 90 ? ['Budget utilization is very high'] : []
    }
  end
  
  def calculate_average_completion_time(tasks)
    completed = tasks.completed
    return 0 if completed.empty?
    
    total_time = completed.sum do |task|
      (task.updated_at - task.created_at) / 1.day
    end
    
    (total_time / completed.count).round(2)
  end
  
  def revenue_breakdown_by_category
    return {} unless @festival
    @festival.revenues.confirmed.group(:revenue_type).sum(:amount)
  end
  
  def get_top_vendors
    return [] unless @festival
    @festival.vendor_applications.approved.includes(:user).limit(5).map do |app|
      {
        name: app.business_name,
        user: app.user.first_name + ' ' + app.user.last_name,
        status: app.status
      }
    end
  end
  
  def calculate_layout_efficiency
    # Simple calculation based on venue utilization
    return 0 unless @festival
    venues = @festival.venues
    return 0 if venues.empty?
    
    total_capacity = venues.sum(:capacity)
    allocated = @festival.booths.count
    
    return 0 if total_capacity.zero?
    (allocated.to_f / total_capacity * 100).round(2)
  end
  
  def calculate_messages_per_user
    return 0 unless @festival
    
    total_messages = @festival.chat_rooms.joins(:chat_messages).count
    active_users = @festival.chat_rooms.joins(:chat_room_members).distinct.count('chat_room_members.user_id')
    
    return 0 if active_users.zero?
    (total_messages.to_f / active_users).round(2)
  end
  
  def calculate_engagement_score
    # Simple engagement score based on activity
    return 0 unless @festival
    
    forum_activity = @festival.forums.joins(:forum_posts).count
    chat_activity = @festival.chat_rooms.joins(:chat_messages).count
    vendor_activity = @festival.vendor_applications.count
    
    (forum_activity + chat_activity + vendor_activity).to_f
  end
  
  def calculate_message_trends
    return {} unless @festival
    
    # Get message counts for last 7 days
    7.times.map do |i|
      date = i.days.ago.to_date
      count = @festival.chat_rooms.joins(:chat_messages)
                      .where(chat_messages: { created_at: date.beginning_of_day..date.end_of_day })
                      .count
      { date: date, count: count }
    end
  end
  
  def get_popular_topics
    return [] unless @festival
    
    @festival.forums.joins(:forum_threads)
             .group('forum_threads.title')
             .order('COUNT(forum_threads.id) DESC')
             .limit(5)
             .count
             .keys
  end
  
  def budget_trend_data
    return {} unless @festival
    # Simplified budget trend - in real implementation would track over time
    {
      current_utilization: @festival.budget_utilization_rate,
      trend: 'stable' # Would calculate actual trend
    }
  end
  
  def task_completion_trend_data
    return {} unless @festival
    {
      current_rate: @festival.completion_rate,
      trend: 'improving' # Would calculate actual trend
    }
  end
  
  def vendor_application_trend_data
    return {} unless @festival
    {
      total_applications: @festival.vendor_applications.count,
      trend: 'stable' # Would calculate actual trend
    }
  end
  
  def communication_trend_data
    return {} unless @festival
    {
      total_messages: @festival.chat_rooms.joins(:chat_messages).count + @festival.forums.joins(:forum_posts).count,
      trend: 'increasing' # Would calculate actual trend
    }
  end
  
  def forecast_budget_completion
    return {} unless @festival
    {
      projected_completion: @festival.budget_utilization_rate,
      confidence: 'medium'
    }
  end
  
  def forecast_task_completion
    return {} unless @festival
    {
      projected_completion: @festival.completion_rate,
      confidence: 'high'
    }
  end
  
  def assess_project_risks
    return {} unless @festival
    risks = []
    
    if @festival.budget_utilization_rate > 90
      risks << 'Budget overrun risk'
    end
    
    if @festival.completion_rate < 70
      risks << 'Timeline risk'
    end
    
    {
      high_risk: risks.count > 1,
      risks: risks
    }
  end
  
  def convert_to_csv(data)
    # Simplified CSV conversion
    "Overview,Budget,Tasks,Vendors\n#{data[:overview]&.values&.join(',')},#{data[:budget_analytics]&.values&.join(',')},#{data[:task_analytics]&.values&.join(',')},#{data[:vendor_analytics]&.values&.join(',')}"
  end
end