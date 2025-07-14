class BudgetReport
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :festival
  attribute :start_date, :date
  attribute :end_date, :date

  validates :festival, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  def initialize(attributes = {})
    super
    # Only set defaults if not explicitly provided in attributes
    unless attributes.key?(:start_date) || attributes.key?("start_date")
      self.start_date = festival&.start_date&.to_date || Date.current.beginning_of_month
    end
    unless attributes.key?(:end_date) || attributes.key?("end_date")
      self.end_date = festival&.end_date&.to_date || Date.current.end_of_month
    end
  end

  def total_budget_limit
    budget_categories.sum(:budget_limit)
  end

  def total_expenses
    expenses_in_period.sum(:amount)
  end

  def total_revenues
    revenues_in_period.sum(:amount)
  end

  def net_balance
    total_revenues - total_expenses
  end

  def budget_utilization_percentage
    return 0 if total_budget_limit.zero?
    (total_expenses / total_budget_limit * 100).round(2)
  end

  def expenses_by_category
    budget_categories.includes(:expenses).map do |category|
      category_expenses = category.expenses.where(
        expense_date: start_date..end_date,
        status: "approved"
      ).sum(:amount)

      {
        category: category,
        amount: category_expenses,
        percentage: category.budget_limit.zero? ? 0 : (category_expenses / category.budget_limit * 100).round(2)
      }
    end.sort_by { |item| -item[:amount] }
  end

  def revenues_by_type
    Revenue::REVENUE_TYPES.map do |type|
      type_revenues = revenues_in_period.where(revenue_type: type).sum(:amount)

      {
        type: type,
        type_text: revenue_type_text(type),
        amount: type_revenues,
        percentage: total_revenues.zero? ? 0 : (type_revenues / total_revenues * 100).round(2)
      }
    end.select { |item| item[:amount] > 0 }.sort_by { |item| -item[:amount] }
  end

  def over_budget_categories
    budget_categories.select(&:over_budget?)
  end

  def near_budget_limit_categories(threshold = 0.8)
    budget_categories.select { |category| category.near_budget_limit?(threshold) }
  end

  def expenses_by_month
    expenses_in_period.group_by_month(:expense_date).sum(:amount)
  end

  def revenues_by_month
    revenues_in_period.group_by_month(:revenue_date).sum(:amount)
  end

  def pending_approvals_count
    festival.budget_approvals.pending.count
  end

  def pending_expenses_count
    festival.expenses.pending_approval.count
  end

  def approved_expenses_count
    expenses_in_period.approved.count
  end

  def confirmed_revenues_count
    revenues_in_period.confirmed.count
  end

  def budget_variance_analysis
    budget_categories.map do |category|
      actual_expenses = category.expenses.where(
        expense_date: start_date..end_date,
        status: "approved"
      ).sum(:amount)

      variance = category.budget_limit - actual_expenses
      variance_percentage = category.budget_limit.zero? ? 0 : (variance / category.budget_limit * 100).round(2)

      {
        category: category,
        budgeted: category.budget_limit,
        actual: actual_expenses,
        variance: variance,
        variance_percentage: variance_percentage,
        status: variance >= 0 ? "under_budget" : "over_budget"
      }
    end.sort_by { |item| item[:variance_percentage] }
  end

  def cash_flow_projection(months_ahead = 3)
    projections = []

    (0..months_ahead).each do |month_offset|
      projection_date = Date.current.beginning_of_month + month_offset.months

      # 過去のデータから月平均を計算
      avg_expenses = festival.expenses.approved
                            .where(expense_date: 3.months.ago..Date.current)
                            .group_by_month(:expense_date)
                            .average(:amount) || 0

      avg_revenues = festival.revenues.confirmed
                            .where(revenue_date: 3.months.ago..Date.current)
                            .group_by_month(:revenue_date)
                            .average(:amount) || 0

      projections << {
        month: projection_date,
        projected_expenses: avg_expenses,
        projected_revenues: avg_revenues,
        projected_balance: avg_revenues - avg_expenses
      }
    end

    projections
  end

  def export_to_csv
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "カテゴリ", "予算額", "実際の支出", "差額", "使用率%" ]

      expenses_by_category.each do |item|
        csv << [
          item[:category].name,
          item[:category].budget_limit,
          item[:amount],
          item[:category].budget_limit - item[:amount],
          item[:percentage]
        ]
      end
    end
  end

  def export_to_json
    {
      festival: festival.name,
      period: "#{start_date} - #{end_date}",
      summary: {
        total_budget: total_budget_limit,
        total_expenses: total_expenses,
        total_revenues: total_revenues,
        net_balance: net_balance,
        utilization_percentage: budget_utilization_percentage
      },
      categories: expenses_by_category,
      revenues: revenues_by_type,
      variance_analysis: budget_variance_analysis,
      alerts: {
        over_budget_categories: over_budget_categories.count,
        near_limit_categories: near_budget_limit_categories.count,
        pending_approvals: pending_approvals_count
      }
    }.to_json
  end

  private

  def budget_categories
    @budget_categories ||= festival.budget_categories.includes(:expenses, :revenues)
  end

  def expenses_in_period
    @expenses_in_period ||= festival.expenses.where(
      expense_date: start_date..end_date,
      status: "approved"
    )
  end

  def revenues_in_period
    @revenues_in_period ||= festival.revenues.where(
      revenue_date: start_date..end_date,
      status: %w[confirmed received]
    )
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

  def end_date_after_start_date
    return unless start_date && end_date

    errors.add(:end_date, "終了日は開始日より後である必要があります") if end_date < start_date
  end
end
