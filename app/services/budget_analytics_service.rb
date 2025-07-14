class BudgetAnalyticsService
  def initialize(festival)
    @festival = festival
  end

  def generate_dashboard_data
    {
      overview: overview_metrics,
      category_breakdown: category_breakdown,
      revenue_breakdown: revenue_breakdown,
      trends: trend_analysis,
      alerts: budget_alerts,
      approvals: approval_metrics
    }
  end

  def overview_metrics
    {
      total_budget: @festival.budget_categories.sum(:budget_limit),
      total_expenses: @festival.expenses.approved.sum(:amount),
      total_revenues: @festival.revenues.confirmed.sum(:amount),
      pending_expenses: @festival.expenses.pending_approval.sum(:amount),
      pending_revenues: @festival.revenues.by_status("pending").sum(:amount),
      budget_utilization: calculate_budget_utilization,
      net_balance: calculate_net_balance,
      variance: calculate_total_variance
    }
  end

  def category_breakdown
    @festival.budget_categories.includes(:expenses).map do |category|
      actual_expenses = category.expenses.approved.sum(:amount)

      {
        id: category.id,
        name: category.name,
        budget_limit: category.budget_limit,
        actual_expenses: actual_expenses,
        remaining_budget: category.budget_remaining,
        utilization_percentage: category.budget_usage_percentage,
        status: determine_category_status(category),
        expense_count: category.expenses.count,
        last_expense_date: category.expenses.approved.maximum(:expense_date)
      }
    end.sort_by { |cat| -cat[:actual_expenses] }
  end

  def revenue_breakdown
    Revenue::REVENUE_TYPES.map do |type|
      revenues = @festival.revenues.by_type(type).confirmed
      total_amount = revenues.sum(:amount)

      {
        type: type,
        type_text: revenue_type_text(type),
        total_amount: total_amount,
        count: revenues.count,
        average_amount: revenues.count > 0 ? total_amount / revenues.count : 0,
        last_revenue_date: revenues.maximum(:revenue_date)
      }
    end.select { |rev| rev[:total_amount] > 0 }.sort_by { |rev| -rev[:total_amount] }
  end

  def trend_analysis
    {
      monthly_expenses: monthly_expense_trend,
      monthly_revenues: monthly_revenue_trend,
      category_trends: category_trend_analysis,
      seasonal_patterns: seasonal_analysis
    }
  end

  def budget_alerts
    alerts = []

    # 予算超過カテゴリ
    over_budget = @festival.budget_categories.select(&:over_budget?)
    over_budget.each do |category|
      alerts << {
        type: "budget_exceeded",
        severity: "high",
        category: category.name,
        message: "予算超過: #{category.name} (#{category.budget_usage_percentage}%使用)",
        amount_over: category.total_budget_used - category.budget_limit
      }
    end

    # 予算上限近接カテゴリ
    near_limit = @festival.budget_categories.select { |cat| cat.near_budget_limit?(0.8) && !cat.over_budget? }
    near_limit.each do |category|
      alerts << {
        type: "budget_warning",
        severity: "medium",
        category: category.name,
        message: "予算残り僅か: #{category.name} (#{category.budget_usage_percentage}%使用)",
        remaining_amount: category.budget_remaining
      }
    end

    # 承認待ち支出の多いカテゴリ
    categories_with_pending = @festival.budget_categories.joins(:expenses)
                                     .where(expenses: { status: "pending" })
                                     .group("budget_categories.id")
                                     .having("COUNT(expenses.id) >= 5")

    categories_with_pending.each do |category|
      pending_count = category.expenses.pending_approval.count
      alerts << {
        type: "pending_expenses",
        severity: "low",
        category: category.name,
        message: "承認待ち支出が多数: #{category.name} (#{pending_count}件)",
        pending_count: pending_count
      }
    end

    alerts.sort_by { |alert| alert[:severity] == "high" ? 0 : alert[:severity] == "medium" ? 1 : 2 }
  end

  def approval_metrics
    {
      pending_budget_approvals: @festival.budget_approvals.pending.count,
      pending_expenses: @festival.expenses.pending_approval.count,
      pending_revenues: @festival.revenues.by_status("pending").count,
      average_approval_time: calculate_average_approval_time,
      approval_rates: calculate_approval_rates
    }
  end

  def forecast_analysis(months_ahead = 3)
    base_date = Date.current
    forecasts = []

    (1..months_ahead).each do |month|
      forecast_date = base_date + month.months

      # 過去3ヶ月の平均を基に予測
      historical_expenses = @festival.expenses.approved
                                   .where(expense_date: 3.months.ago..base_date)
                                   .group_by_month(:expense_date)
                                   .average(:amount) || 0

      historical_revenues = @festival.revenues.confirmed
                                   .where(revenue_date: 3.months.ago..base_date)
                                   .group_by_month(:revenue_date)
                                   .average(:amount) || 0

      forecasts << {
        month: forecast_date.strftime("%Y-%m"),
        projected_expenses: historical_expenses,
        projected_revenues: historical_revenues,
        projected_balance: historical_revenues - historical_expenses,
        confidence_level: calculate_forecast_confidence(month)
      }
    end

    forecasts
  end

  def budget_efficiency_score
    total_budget = @festival.budget_categories.sum(:budget_limit)
    return 0 if total_budget.zero?

    # 予算使用効率 (0-100)
    utilization_score = [ budget_utilization_percentage, 100 ].min

    # 予算超過ペナルティ
    over_budget_penalty = @festival.budget_categories.select(&:over_budget?).count * 10

    # 承認プロセス効率
    approval_efficiency = calculate_approval_efficiency_score

    # 収益効率
    revenue_efficiency = calculate_revenue_efficiency_score

    base_score = (utilization_score + approval_efficiency + revenue_efficiency) / 3
    final_score = [ base_score - over_budget_penalty, 0 ].max

    {
      total_score: final_score.round(1),
      utilization_score: utilization_score.round(1),
      approval_efficiency: approval_efficiency.round(1),
      revenue_efficiency: revenue_efficiency.round(1),
      penalty: over_budget_penalty
    }
  end

  def export_analytics_report(format = :json)
    data = {
      festival: @festival.name,
      generated_at: Time.current,
      overview: overview_metrics,
      categories: category_breakdown,
      revenues: revenue_breakdown,
      trends: trend_analysis,
      alerts: budget_alerts,
      forecast: forecast_analysis,
      efficiency_score: budget_efficiency_score
    }

    case format
    when :json
      data.to_json
    when :csv
      generate_csv_report(data)
    else
      data
    end
  end

  private

  def calculate_budget_utilization
    total_budget = @festival.budget_categories.sum(:budget_limit)
    return 0 if total_budget.zero?

    total_expenses = @festival.expenses.approved.sum(:amount)
    (total_expenses / total_budget * 100).round(2)
  end

  def budget_utilization_percentage
    calculate_budget_utilization
  end

  def calculate_net_balance
    total_revenues = @festival.revenues.confirmed.sum(:amount)
    total_expenses = @festival.expenses.approved.sum(:amount)
    total_revenues - total_expenses
  end

  def calculate_total_variance
    total_budget = @festival.budget_categories.sum(:budget_limit)
    total_expenses = @festival.expenses.approved.sum(:amount)
    total_budget - total_expenses
  end

  def determine_category_status(category)
    if category.over_budget?
      "over_budget"
    elsif category.near_budget_limit?(0.9)
      "near_limit"
    elsif category.budget_usage_percentage < 50
      "under_utilized"
    else
      "on_track"
    end
  end

  def monthly_expense_trend
    @festival.expenses.approved
             .where(expense_date: 6.months.ago..Date.current)
             .group_by_month(:expense_date)
             .sum(:amount)
  end

  def monthly_revenue_trend
    @festival.revenues.confirmed
             .where(revenue_date: 6.months.ago..Date.current)
             .group_by_month(:revenue_date)
             .sum(:amount)
  end

  def category_trend_analysis
    @festival.budget_categories.map do |category|
      monthly_data = category.expenses.approved
                            .where(expense_date: 3.months.ago..Date.current)
                            .group_by_month(:expense_date)
                            .sum(:amount)

      {
        category: category.name,
        trend: calculate_trend_direction(monthly_data.values),
        monthly_average: monthly_data.values.sum / [ monthly_data.count, 1 ].max
      }
    end
  end

  def seasonal_analysis
    # 四半期ごとの支出パターン分析
    quarters = {}

    (0..3).each do |quarter|
      start_date = Date.current.beginning_of_year + quarter.quarters
      end_date = start_date.end_of_quarter

      expenses = @festival.expenses.approved
                          .where(expense_date: start_date..end_date)
                          .sum(:amount)

      quarters["Q#{quarter + 1}"] = expenses
    end

    quarters
  end

  def calculate_average_approval_time
    approved_expenses = @festival.expenses.approved
                               .where("updated_at > created_at")

    return 0 if approved_expenses.empty?

    total_time = approved_expenses.sum do |expense|
      (expense.updated_at - expense.created_at) / 1.day
    end

    (total_time / approved_expenses.count).round(1)
  end

  def calculate_approval_rates
    total_budget_requests = @festival.budget_approvals.count
    approved_budget_requests = @festival.budget_approvals.approved.count

    total_expense_requests = @festival.expenses.where(status: %w[approved rejected]).count
    approved_expense_requests = @festival.expenses.approved.count

    {
      budget_approval_rate: total_budget_requests > 0 ? (approved_budget_requests.to_f / total_budget_requests * 100).round(1) : 0,
      expense_approval_rate: total_expense_requests > 0 ? (approved_expense_requests.to_f / total_expense_requests * 100).round(1) : 0
    }
  end

  def calculate_forecast_confidence(months_ahead)
    # 予測の信頼度は時間が経つほど下がる
    base_confidence = 85
    confidence_decay = months_ahead * 15
    [ base_confidence - confidence_decay, 30 ].max
  end

  def calculate_approval_efficiency_score
    avg_approval_time = calculate_average_approval_time
    approval_rates = calculate_approval_rates

    # 承認時間が短く、承認率が適正な範囲にあるほど高スコア
    time_score = avg_approval_time > 0 ? [ 100 - (avg_approval_time * 5), 0 ].max : 100
    rate_score = approval_rates[:expense_approval_rate]

    (time_score + rate_score) / 2
  end

  def calculate_revenue_efficiency_score
    total_revenues = @festival.revenues.confirmed.sum(:amount)
    total_expenses = @festival.expenses.approved.sum(:amount)

    return 0 if total_expenses.zero?

    revenue_ratio = (total_revenues / total_expenses * 100)
    [ revenue_ratio, 100 ].min
  end

  def calculate_trend_direction(values)
    return "stable" if values.length < 2

    increases = 0
    decreases = 0

    values.each_cons(2) do |prev, curr|
      if curr > prev
        increases += 1
      elsif curr < prev
        decreases += 1
      end
    end

    if increases > decreases
      "increasing"
    elsif decreases > increases
      "decreasing"
    else
      "stable"
    end
  end

  def revenue_type_text(type)
    case type
    when "ticket_sales" then "チケット売上"
    when "sponsorship" then "スポンサーシップ"
    when "vendor_fees" then "ベンダー出店料"
    when "donation" then "寄付"
    when "grant" then "助成金"
    when "merchandise" then "グッズ売上"
    when "other" then "その他"
    else type.humanize
    end
  end

  def generate_csv_report(data)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "項目", "値" ]
      csv << [ "フェスティバル名", data[:festival] ]
      csv << [ "総予算", data[:overview][:total_budget] ]
      csv << [ "総支出", data[:overview][:total_expenses] ]
      csv << [ "総収入", data[:overview][:total_revenues] ]
      csv << [ "予算使用率", "#{data[:overview][:budget_utilization]}%" ]
      csv << []
      csv << [ "カテゴリ別詳細" ]
      csv << [ "カテゴリ名", "予算額", "実際の支出", "使用率%", "ステータス" ]

      data[:categories].each do |category|
        csv << [
          category[:name],
          category[:budget_limit],
          category[:actual_expenses],
          category[:utilization_percentage],
          category[:status]
        ]
      end
    end
  end
end
