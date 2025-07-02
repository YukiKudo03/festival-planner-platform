class Admin::VendorApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_vendor_application, only: [:show, :review, :approve, :reject, :request_changes, :conditionally_approve, :start_review]

  def index
    @applications = VendorApplication.includes(:festival, :user, :application_reviews)
                                    .order(created_at: :desc)
    
    # フィルタリング
    @applications = @applications.where(status: params[:status]) if params[:status].present?
    @applications = @applications.where(priority: params[:priority]) if params[:priority].present?
    @applications = @applications.joins(:festival).where(festivals: { id: params[:festival_id] }) if params[:festival_id].present?
    
    # ページネーション（必要に応じて）
    @applications = @applications.limit(100)
    
    # 統計情報
    @stats = {
      total: VendorApplication.count,
      pending: VendorApplication.submitted.count,
      under_review: VendorApplication.under_review.count,
      approved: VendorApplication.approved.count,
      rejected: VendorApplication.rejected.count,
      overdue: VendorApplication.joins(:festival).where('vendor_applications.review_deadline < ? AND vendor_applications.status IN (?)', Time.current, [:submitted, :under_review]).count
    }
    
    @festivals = Festival.order(:name)
  end

  def show
    @reviews = @application.application_reviews.includes(:reviewer).recent
    @public_comments = @application.public_comments.includes(:user)
    @internal_comments = @application.internal_comments.includes(:user)
  end

  def review
    # 審査画面での詳細表示
    @reviews = @application.application_reviews.includes(:reviewer).recent
    @new_comment = ApplicationComment.new
  end

  def pending
    @applications = VendorApplication.submitted.includes(:festival, :user, :application_reviews)
                                    .order(created_at: :desc)
    render :index
  end

  def under_review
    @applications = VendorApplication.under_review.includes(:festival, :user, :application_reviews)
                                    .order(created_at: :desc)
    render :index
  end

  def overdue
    @applications = VendorApplication.joins(:festival)
                                    .where('vendor_applications.review_deadline < ? AND vendor_applications.status IN (?)', 
                                           Time.current, [:submitted, :under_review])
                                    .includes(:festival, :user, :application_reviews)
                                    .order(:review_deadline)
    render :index
  end

  def start_review
    if @application.start_review!(current_user)
      redirect_to admin_vendor_application_path(@application), notice: '審査を開始しました。'
    else
      redirect_to admin_vendor_application_path(@application), alert: '審査を開始できませんでした。'
    end
  end

  def approve
    comment = params[:comment]
    
    if @application.approve!(current_user, comment)
      redirect_to admin_vendor_application_path(@application), notice: '申請を承認しました。'
    else
      redirect_to admin_vendor_application_path(@application), alert: '承認できませんでした。'
    end
  end

  def reject
    comment = params[:comment]
    
    if comment.present? && @application.reject!(current_user, comment)
      redirect_to admin_vendor_application_path(@application), notice: '申請を却下しました。'
    else
      redirect_to admin_vendor_application_path(@application), alert: '却下できませんでした。却下理由を入力してください。'
    end
  end

  def request_changes
    comment = params[:comment]
    
    if comment.present? && @application.request_changes!(current_user, comment)
      redirect_to admin_vendor_application_path(@application), notice: '修正要求を送信しました。'
    else
      redirect_to admin_vendor_application_path(@application), alert: '修正要求を送信できませんでした。理由を入力してください。'
    end
  end

  def conditionally_approve
    conditions = params[:conditions]
    comment = params[:comment]
    
    if conditions.present? && @application.conditionally_approve!(current_user, conditions, comment)
      redirect_to admin_vendor_application_path(@application), notice: '条件付きで承認しました。'
    else
      redirect_to admin_vendor_application_path(@application), alert: '条件付き承認できませんでした。条件を入力してください。'
    end
  end

  private

  def set_vendor_application
    @application = VendorApplication.find(params[:id])
  end

  def ensure_admin!
    unless current_user&.admin? || current_user&.committee_member? || current_user&.system_admin?
      redirect_to root_path, alert: 'アクセス権限がありません。'
    end
  end
end
