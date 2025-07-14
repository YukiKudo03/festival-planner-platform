class Admin::BudgetCategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_or_committee_member
  before_action :set_festival
  before_action :set_budget_category, only: [ :show, :edit, :update, :destroy ]

  def index
    @budget_categories = @festival.budget_categories.includes(:expenses, :revenues)
                                  .order(:name)
    @total_budget = @budget_categories.sum(:budget_limit)
    @total_expenses = @festival.expenses.approved.sum(:amount)
  end

  def show
    @expenses = @budget_category.expenses.recent.includes(:user)
    @revenues = @budget_category.revenues.recent.includes(:user)
    @budget_usage_chart_data = prepare_budget_usage_data
  end

  def new
    @budget_category = @festival.budget_categories.build
    @parent_categories = @festival.budget_categories.root_categories
  end

  def create
    @budget_category = @festival.budget_categories.build(budget_category_params)

    if @budget_category.save
      redirect_to admin_festival_budget_category_path(@festival, @budget_category),
                  notice: "予算カテゴリが作成されました。"
    else
      @parent_categories = @festival.budget_categories.root_categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @parent_categories = @festival.budget_categories.root_categories
                                  .where.not(id: @budget_category.id)
  end

  def update
    if @budget_category.update(budget_category_params)
      redirect_to admin_festival_budget_category_path(@festival, @budget_category),
                  notice: "予算カテゴリが更新されました。"
    else
      @parent_categories = @festival.budget_categories.root_categories
                                    .where.not(id: @budget_category.id)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @budget_category.expenses.any? || @budget_category.revenues.any?
      redirect_to admin_festival_budget_categories_path(@festival),
                  alert: "支出または収入が登録されているため削除できません。"
    else
      @budget_category.destroy
      redirect_to admin_festival_budget_categories_path(@festival),
                  notice: "予算カテゴリが削除されました。"
    end
  end

  def create_standard_categories
    BudgetCategory.create_standard_categories_for(@festival)
    redirect_to admin_festival_budget_categories_path(@festival),
                notice: "標準予算カテゴリを作成しました。"
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

  def ensure_admin_or_committee_member
    unless current_user.admin? || current_user.committee_member? ||
           current_user.festivals.exists?(params[:festival_id])
      redirect_to root_path, alert: "アクセス権限がありません。"
    end
  end

  def prepare_budget_usage_data
    {
      budget_limit: @budget_category.budget_limit,
      used_amount: @budget_category.total_budget_used,
      remaining_amount: @budget_category.budget_remaining,
      usage_percentage: @budget_category.budget_usage_percentage
    }
  end
end
