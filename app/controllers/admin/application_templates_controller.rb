class Admin::ApplicationTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_application_template, only: [ :show, :edit, :update, :destroy, :activate, :archive, :clone, :preview, :download ]
  before_action :set_festival, only: [ :index, :new, :create ]

  # GET /admin/application_templates
  def index
    @templates = ApplicationTemplate.includes(:festival, :created_by)

    if @festival
      @templates = @templates.for_festival(@festival)
    else
      @templates = @templates.global_templates
    end

    @templates = @templates.where(template_type: params[:type]) if params[:type].present?
    @templates = @templates.where(status: params[:status]) if params[:status].present?
    @templates = @templates.recent.page(params[:page])

    @template_types = ApplicationTemplate.template_types.keys
    @statuses = ApplicationTemplate.statuses.keys
    @festivals = Festival.order(:name)
  end

  # GET /admin/application_templates/:id
  def show
    @sections = @template.template_sections.ordered.includes(:template_fields)
    @usage_stats = @template.usage_statistics
    @validation_errors = @template.validation_errors_summary
  end

  # GET /admin/application_templates/new
  def new
    @template = ApplicationTemplate.new
    @template.festival = @festival
    @template.created_by = current_user
  end

  # POST /admin/application_templates
  def create
    @template = ApplicationTemplate.new(template_params)
    @template.created_by = current_user
    @template.festival = @festival

    if @template.save
      redirect_to admin_application_template_path(@template),
                  notice: "テンプレートが作成されました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/application_templates/:id/edit
  def edit
    unless @template.can_be_edited_by?(current_user)
      redirect_to admin_application_templates_path,
                  alert: "このテンプレートを編集する権限がありません。"
    end
  end

  # PATCH /admin/application_templates/:id
  def update
    unless @template.can_be_edited_by?(current_user)
      redirect_to admin_application_templates_path,
                  alert: "このテンプレートを編集する権限がありません。"
      return
    end

    if @template.update(template_params)
      redirect_to admin_application_template_path(@template),
                  notice: "テンプレートが更新されました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/application_templates/:id
  def destroy
    unless @template.can_be_edited_by?(current_user)
      redirect_to admin_application_templates_path,
                  alert: "このテンプレートを削除する権限がありません。"
      return
    end

    if @template.vendor_applications_using_template.any?
      redirect_to admin_application_template_path(@template),
                  alert: "このテンプレートは使用中のため削除できません。アーカイブしてください。"
      return
    end

    @template.destroy
    redirect_to admin_application_templates_path,
                notice: "テンプレートが削除されました。"
  end

  # POST /admin/application_templates/:id/activate
  def activate
    if @template.update(status: :active)
      redirect_to admin_application_template_path(@template),
                  notice: "テンプレートが有効化されました。"
    else
      redirect_to admin_application_template_path(@template),
                  alert: "テンプレートの有効化に失敗しました。"
    end
  end

  # POST /admin/application_templates/:id/archive
  def archive
    if @template.update(status: :archived)
      redirect_to admin_application_template_path(@template),
                  notice: "テンプレートがアーカイブされました。"
    else
      redirect_to admin_application_template_path(@template),
                  alert: "テンプレートのアーカイブに失敗しました。"
    end
  end

  # POST /admin/application_templates/:id/clone
  def clone
    target_festival = Festival.find_by(id: params[:target_festival_id])

    unless target_festival
      redirect_to admin_application_template_path(@template),
                  alert: "複製先の祭りを選択してください。"
      return
    end

    new_template = @template.clone_for_festival(target_festival, current_user)

    if new_template.persisted?
      redirect_to admin_application_template_path(new_template),
                  notice: "テンプレートが複製されました。"
    else
      redirect_to admin_application_template_path(@template),
                  alert: "テンプレートの複製に失敗しました。"
    end
  end

  # GET /admin/application_templates/:id/preview
  def preview
    @variables = {
      "business_name" => "サンプル事業者",
      "business_type" => "飲食店",
      "representative_name" => "山田太郎",
      "contact_info" => "sample@example.com",
      "products_services" => "たこ焼き、焼きそば",
      "expected_revenue" => "50,000円",
      "required_facilities" => "電源、水道",
      "special_notes" => "特になし"
    }

    @rendered_content = @template.render_content(@variables)

    respond_to do |format|
      format.html
      format.pdf do
        pdf_data = @template.generate_pdf(@variables)
        send_data pdf_data[:content],
                  filename: pdf_data[:filename],
                  type: "application/pdf"
      end
    end
  end

  # GET /admin/application_templates/:id/download
  def download
    if @template.template_file.attached?
      redirect_to rails_blob_path(@template.template_file, disposition: "attachment")
    else
      redirect_to admin_application_template_path(@template),
                  alert: "ダウンロード可能なファイルがありません。"
    end
  end

  # GET /admin/application_templates/bulk_create
  def bulk_create
    @festivals = Festival.order(:name)
  end

  # POST /admin/application_templates/create_defaults
  def create_defaults
    festival = params[:festival_id].present? ? Festival.find(params[:festival_id]) : nil

    begin
      templates = ApplicationTemplate.create_default_templates(festival)
      redirect_to admin_application_templates_path(festival_id: festival&.id),
                  notice: "#{templates.length}個のデフォルトテンプレートが作成されました。"
    rescue => error
      redirect_to admin_application_templates_path,
                  alert: "テンプレートの作成に失敗しました: #{error.message}"
    end
  end

  # GET /admin/application_templates/analytics
  def analytics
    @template_analytics = generate_template_analytics
    @usage_trends = generate_usage_trends
    @popular_templates = generate_popular_templates

    respond_to do |format|
      format.html
      format.json { render json: { analytics: @template_analytics, trends: @usage_trends, popular: @popular_templates } }
    end
  end

  # POST /admin/application_templates/bulk_update_status
  def bulk_update_status
    template_ids = params[:template_ids] || []
    new_status = params[:new_status]

    unless ApplicationTemplate.statuses.key?(new_status)
      redirect_to admin_application_templates_path,
                  alert: "無効なステータスです。"
      return
    end

    success_count = 0
    template_ids.each do |id|
      template = ApplicationTemplate.find_by(id: id)
      if template&.can_be_edited_by?(current_user) && template.update(status: new_status)
        success_count += 1
      end
    end

    redirect_to admin_application_templates_path,
                notice: "#{success_count}個のテンプレートのステータスが更新されました。"
  end

  # GET /admin/application_templates/export
  def export
    @templates = ApplicationTemplate.includes(:festival, :created_by, :template_sections)

    # フィルタリング
    @templates = @templates.where(template_type: params[:type]) if params[:type].present?
    @templates = @templates.where(status: params[:status]) if params[:status].present?
    @templates = @templates.for_festival(params[:festival_id]) if params[:festival_id].present?

    respond_to do |format|
      format.csv do
        headers["Content-Disposition"] = "attachment; filename=\"application_templates_#{Date.current}.csv\""
        headers["Content-Type"] = "text/csv"
      end
      format.json { render json: serialize_templates_for_export(@templates) }
    end
  end

  private

  def set_application_template
    @template = ApplicationTemplate.find(params[:id])
  end

  def set_festival
    @festival = Festival.find_by(id: params[:festival_id])
  end

  def template_params
    params.require(:application_template).permit(
      :name, :description, :template_type, :content, :status, :festival_id,
      :template_file, sample_documents: []
    )
  end

  def generate_template_analytics
    {
      total_templates: ApplicationTemplate.count,
      active_templates: ApplicationTemplate.active.count,
      draft_templates: ApplicationTemplate.draft.count,
      archived_templates: ApplicationTemplate.archived.count,
      templates_by_type: ApplicationTemplate.group(:template_type).count,
      templates_by_festival: ApplicationTemplate.joins(:festival).group("festivals.name").count,
      most_used_template: find_most_used_template,
      least_used_template: find_least_used_template,
      average_usage_per_template: calculate_average_usage
    }
  end

  def generate_usage_trends
    last_30_days = ApplicationTemplate.joins(:vendor_applications_using_template)
                                     .where("vendor_applications.created_at >= ?", 30.days.ago)
                                     .group_by_day("vendor_applications.created_at")
                                     .count

    last_60_days = ApplicationTemplate.joins(:vendor_applications_using_template)
                                     .where("vendor_applications.created_at >= ?", 60.days.ago)
                                     .where("vendor_applications.created_at < ?", 30.days.ago)
                                     .group_by_day("vendor_applications.created_at")
                                     .count

    {
      last_30_days: last_30_days,
      previous_30_days: last_60_days,
      growth_rate: calculate_usage_growth_rate(last_30_days.values.sum, last_60_days.values.sum)
    }
  end

  def generate_popular_templates
    ApplicationTemplate.left_joins(:vendor_applications_using_template)
                      .group("application_templates.id", "application_templates.name")
                      .order("COUNT(vendor_applications.id) DESC")
                      .limit(10)
                      .count
  end

  def find_most_used_template
    ApplicationTemplate.left_joins(:vendor_applications_using_template)
                      .group("application_templates.id")
                      .order("COUNT(vendor_applications.id) DESC")
                      .first
  end

  def find_least_used_template
    ApplicationTemplate.left_joins(:vendor_applications_using_template)
                      .group("application_templates.id")
                      .order("COUNT(vendor_applications.id) ASC")
                      .first
  end

  def calculate_average_usage
    total_usage = VendorApplication.where.not(application_template: nil).count
    total_templates = ApplicationTemplate.count

    return 0 if total_templates.zero?
    (total_usage.to_f / total_templates).round(2)
  end

  def calculate_usage_growth_rate(current, previous)
    return 0 if previous.zero?
    (((current - previous).to_f / previous) * 100).round(2)
  end

  def serialize_templates_for_export(templates)
    templates.map do |template|
      {
        id: template.id,
        name: template.name,
        type: template.type_text,
        status: template.status_text,
        festival: template.festival&.name || "グローバル",
        created_by: template.created_by&.display_name,
        created_at: template.created_at.strftime("%Y-%m-%d %H:%M"),
        updated_at: template.updated_at.strftime("%Y-%m-%d %H:%M"),
        usage_count: template.vendor_applications_using_template.count,
        sections_count: template.template_sections.count
      }
    end
  end

  def ensure_admin!
    unless current_user&.admin? || current_user&.committee_member? || current_user&.system_admin?
      redirect_to root_path, alert: "アクセス権限がありません。"
    end
  end
end
