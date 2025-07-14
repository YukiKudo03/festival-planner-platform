class Admin::ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_or_committee_member
  before_action :set_festival
  before_action :set_expense, only: [ :show, :edit, :update, :destroy, :approve, :reject ]

  def index
    @expenses = @festival.expenses.includes(:budget_category, :user)
                         .order(created_at: :desc)

    # フィルタリング
    @expenses = @expenses.by_status(params[:status]) if params[:status].present?
    @expenses = @expenses.by_category(params[:category_id]) if params[:category_id].present?
    @expenses = @expenses.by_date_range(params[:start_date], params[:end_date]) if params[:start_date].present? && params[:end_date].present?

    @expenses = @expenses.page(params[:page])
    @budget_categories = @festival.budget_categories.order(:name)
    @status_counts = calculate_status_counts
  end

  def show
    @approval_history = @expense.budget_category.budget_approvals.recent
  end

  def new
    @expense = @festival.expenses.build
    @budget_categories = @festival.budget_categories.order(:name)
  end

  def create
    @expense = @festival.expenses.build(expense_params)
    @expense.user = current_user

    if @expense.save
      redirect_to admin_festival_expense_path(@festival, @expense),
                  notice: "支出が登録されました。"
    else
      @budget_categories = @festival.budget_categories.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return redirect_with_permission_error unless @expense.can_be_modified_by?(current_user)
    @budget_categories = @festival.budget_categories.order(:name)
  end

  def update
    return redirect_with_permission_error unless @expense.can_be_modified_by?(current_user)

    if @expense.update(expense_params)
      redirect_to admin_festival_expense_path(@festival, @expense),
                  notice: "支出が更新されました。"
    else
      @budget_categories = @festival.budget_categories.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    return redirect_with_permission_error unless @expense.can_be_modified_by?(current_user)

    @expense.destroy
    redirect_to admin_festival_expenses_path(@festival),
                notice: "支出が削除されました。"
  end

  def approve
    return redirect_with_permission_error unless @expense.can_be_approved_by?(current_user)

    if @expense.approve!(current_user, params[:notes])
      redirect_to admin_festival_expense_path(@festival, @expense),
                  notice: "支出を承認しました。"
    else
      redirect_to admin_festival_expense_path(@festival, @expense),
                  alert: "承認に失敗しました。"
    end
  end

  def reject
    return redirect_with_permission_error unless @expense.can_be_approved_by?(current_user)

    if @expense.reject!(current_user, params[:reason])
      redirect_to admin_festival_expense_path(@festival, @expense),
                  notice: "支出を却下しました。"
    else
      redirect_to admin_festival_expense_path(@festival, @expense),
                  alert: "却下に失敗しました。理由を入力してください。"
    end
  end

  def bulk_approve
    expense_ids = params[:expense_ids] || []
    approved_count = 0

    expense_ids.each do |expense_id|
      expense = @festival.expenses.find(expense_id)
      if expense.can_be_approved_by?(current_user) && expense.approve!(current_user)
        approved_count += 1
      end
    end

    redirect_to admin_festival_expenses_path(@festival),
                notice: "#{approved_count}件の支出を一括承認しました。"
  end

  def export
    respond_to do |format|
      format.csv do
        expenses = @festival.expenses.includes(:budget_category, :user)
        csv_data = generate_expenses_csv(expenses)
        send_data csv_data, filename: "expenses_#{@festival.name}_#{Date.current}.csv"
      end
    end
  end

  private

  def set_festival
    @festival = current_user.admin? || current_user.committee_member? ?
                Festival.find(params[:festival_id]) :
                current_user.festivals.find(params[:festival_id])
  end

  def set_expense
    @expense = @festival.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:budget_category_id, :amount, :description,
                                   :expense_date, :payment_method, :status,
                                   receipts: [])
  end

  def ensure_admin_or_committee_member
    unless current_user.admin? || current_user.committee_member? ||
           current_user.festivals.exists?(params[:festival_id])
      redirect_to root_path, alert: "アクセス権限がありません。"
    end
  end

  def redirect_with_permission_error
    redirect_to admin_festival_expenses_path(@festival),
                alert: "この操作を実行する権限がありません。"
  end

  def calculate_status_counts
    {
      all: @festival.expenses.count,
      draft: @festival.expenses.by_status("draft").count,
      pending: @festival.expenses.by_status("pending").count,
      approved: @festival.expenses.by_status("approved").count,
      rejected: @festival.expenses.by_status("rejected").count
    }
  end

  def generate_expenses_csv(expenses)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "ID", "日付", "カテゴリ", "金額", "説明", "支払方法", "ステータス", "申請者" ]

      expenses.each do |expense|
        csv << [
          expense.id,
          expense.expense_date,
          expense.budget_category.name,
          expense.amount,
          expense.description,
          expense.payment_method_text,
          expense.status_text,
          expense.user.name
        ]
      end
    end
  end
end
