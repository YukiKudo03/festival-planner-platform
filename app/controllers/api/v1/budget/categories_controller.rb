class Api::V1::Budget::CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_budget_category, only: [ :show, :update, :destroy ]
  before_action :ensure_access_permission

  def index
    @budget_categories = @festival.budget_categories.includes(:expenses, :revenues)

    render json: {
      budget_categories: @budget_categories.map { |category| budget_category_json(category) },
      total_budget: @budget_categories.sum(:budget_limit),
      total_expenses: @festival.expenses.approved.sum(:amount),
      total_revenues: @festival.revenues.confirmed.sum(:amount)
    }
  end

  def show
    render json: {
      budget_category: budget_category_json(@budget_category),
      expenses: @budget_category.expenses.recent.limit(10).map { |expense| expense_json(expense) },
      revenues: @budget_category.revenues.recent.limit(10).map { |revenue| revenue_json(revenue) },
      usage_data: {
        budget_limit: @budget_category.budget_limit,
        used_amount: @budget_category.total_budget_used,
        remaining_amount: @budget_category.budget_remaining,
        usage_percentage: @budget_category.budget_usage_percentage
      }
    }
  end

  def create
    @budget_category = @festival.budget_categories.build(budget_category_params)

    if @budget_category.save
      render json: {
        budget_category: budget_category_json(@budget_category),
        message: "予算カテゴリが作成されました。"
      }, status: :created
    else
      render json: {
        errors: @budget_category.errors.full_messages,
        message: "予算カテゴリの作成に失敗しました。"
      }, status: :unprocessable_entity
    end
  end

  def update
    if @budget_category.update(budget_category_params)
      render json: {
        budget_category: budget_category_json(@budget_category),
        message: "予算カテゴリが更新されました。"
      }
    else
      render json: {
        errors: @budget_category.errors.full_messages,
        message: "予算カテゴリの更新に失敗しました。"
      }, status: :unprocessable_entity
    end
  end

  def destroy
    if @budget_category.expenses.any? || @budget_category.revenues.any?
      render json: {
        message: "支出または収入が登録されているため削除できません。"
      }, status: :unprocessable_entity
    else
      @budget_category.destroy
      render json: {
        message: "予算カテゴリが削除されました。"
      }
    end
  end

  private

  def set_festival
    @festival = current_user.admin? || current_user.committee_member? ?
                Festival.find(params[:festival_id]) :
                current_user.festivals.find(params[:festival_id])
  end

  def set_budget_category
    @budget_category = @festival.budget_categories.find(params[:id])
  end

  def budget_category_params
    params.require(:budget_category).permit(:name, :description, :budget_limit, :parent_id)
  end

  def ensure_access_permission
    unless current_user.admin? || current_user.committee_member? ||
           current_user.festivals.exists?(@festival.id)
      render json: { error: "アクセス権限がありません。" }, status: :forbidden
    end
  end

  def budget_category_json(category)
    {
      id: category.id,
      name: category.name,
      description: category.description,
      budget_limit: category.budget_limit,
      budget_limit_formatted: "¥#{category.budget_limit.to_i.to_s(:delimited)}",
      total_expenses: category.total_expenses,
      total_expenses_formatted: "¥#{category.total_expenses.to_i.to_s(:delimited)}",
      total_revenues: category.total_revenues,
      total_revenues_formatted: "¥#{category.total_revenues.to_i.to_s(:delimited)}",
      budget_remaining: category.budget_remaining,
      budget_remaining_formatted: "¥#{category.budget_remaining.to_i.to_s(:delimited)}",
      usage_percentage: category.budget_usage_percentage,
      over_budget: category.over_budget?,
      near_budget_limit: category.near_budget_limit?,
      hierarchy_path: category.hierarchy_path,
      parent_id: category.parent_id,
      expenses_count: category.expenses.count,
      revenues_count: category.revenues.count,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end

  def expense_json(expense)
    {
      id: expense.id,
      amount: expense.amount,
      amount_formatted: expense.amount_formatted,
      description: expense.description,
      expense_date: expense.expense_date,
      payment_method: expense.payment_method,
      payment_method_text: expense.payment_method_text,
      status: expense.status,
      status_text: expense.status_text,
      status_color: expense.status_color,
      user_name: expense.user.name,
      created_at: expense.created_at
    }
  end

  def revenue_json(revenue)
    {
      id: revenue.id,
      amount: revenue.amount,
      amount_formatted: revenue.amount_formatted,
      description: revenue.description,
      revenue_date: revenue.revenue_date,
      revenue_type: revenue.revenue_type,
      revenue_type_text: revenue.revenue_type_text,
      status: revenue.status,
      status_text: revenue.status_text,
      status_color: revenue.status_color,
      user_name: revenue.user.name,
      created_at: revenue.created_at
    }
  end
end
