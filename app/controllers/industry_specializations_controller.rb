# frozen_string_literal: true

class IndustrySpecializationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_industry_specialization, only: [:show, :edit, :update, :destroy, :activate, :complete]
  before_action :authorize_festival_access

  def index
    @industry_specializations = @festival.industry_specializations.includes(:industry_requirements, :industry_certifications)
    @available_industries = IndustrySpecialization::INDUSTRY_TYPES
    @specialization_stats = calculate_specialization_stats
  end

  def show
    @compliance_checklist = @industry_specialization.compliance_checklist
    @industry_kpis = @industry_specialization.industry_kpis
    @vendor_requirements = @industry_specialization.vendor_requirements
    @progress_percentage = @industry_specialization.specialization_progress
  end

  def new
    @industry_specialization = @festival.industry_specializations.build
    @available_industries = IndustrySpecialization::INDUSTRY_TYPES
    @specialization_levels = IndustrySpecialization::SPECIALIZATION_LEVELS
  end

  def create
    @industry_specialization = @festival.industry_specializations.build(industry_specialization_params)
    
    if @industry_specialization.save
      redirect_to [@festival, @industry_specialization], 
                  notice: '業界特化設定が正常に作成されました。'
    else
      @available_industries = IndustrySpecialization::INDUSTRY_TYPES
      @specialization_levels = IndustrySpecialization::SPECIALIZATION_LEVELS
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_industries = IndustrySpecialization::INDUSTRY_TYPES
    @specialization_levels = IndustrySpecialization::SPECIALIZATION_LEVELS
  end

  def update
    if @industry_specialization.update(industry_specialization_params)
      redirect_to [@festival, @industry_specialization], 
                  notice: '業界特化設定が正常に更新されました。'
    else
      @available_industries = IndustrySpecialization::INDUSTRY_TYPES
      @specialization_levels = IndustrySpecialization::SPECIALIZATION_LEVELS
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @industry_specialization.destroy
    redirect_to festival_industry_specializations_path(@festival), 
                notice: '業界特化設定が削除されました。'
  end

  def activate
    if @industry_specialization.activate!
      redirect_to [@festival, @industry_specialization], 
                  notice: '業界特化機能が有効化されました。'
    else
      redirect_to [@festival, @industry_specialization], 
                  alert: '有効化に必要な要件が満たされていません。'
    end
  end

  def complete
    completion_notes = params[:completion_notes]
    
    if @industry_specialization.complete!(completion_notes: completion_notes)
      redirect_to [@festival, @industry_specialization], 
                  notice: '業界特化プログラムが完了しました。'
    else
      redirect_to [@festival, @industry_specialization], 
                  alert: '完了処理でエラーが発生しました。'
    end
  end

  def update_metrics
    @industry_specialization = @festival.industry_specializations.find(params[:id])
    metrics_data = params[:metrics] || {}
    
    begin
      @industry_specialization.update_metrics(metrics_data)
      render json: { 
        status: 'success', 
        message: 'メトリクスが更新されました',
        updated_kpis: @industry_specialization.industry_kpis
      }
    rescue => e
      render json: { 
        status: 'error', 
        message: "更新エラー: #{e.message}" 
      }, status: :unprocessable_entity
    end
  end

  def industry_dashboard
    @industry_specialization = @festival.industry_specializations.find(params[:id])
    @recent_metrics = @industry_specialization.industry_metrics.recent.limit(10)
    @compliance_score = @industry_specialization.send(:calculate_compliance_score)
    @missing_certifications = @industry_specialization.missing_certifications
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          specialization: @industry_specialization.summary,
          metrics: @recent_metrics,
          compliance_score: @compliance_score,
          missing_certifications: @missing_certifications
        }
      }
    end
  end

  private

  def set_festival
    @festival = current_user.festivals.find(params[:festival_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to festivals_path, alert: 'フェスティバルが見つかりません。'
  end

  def set_industry_specialization
    @industry_specialization = @festival.industry_specializations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to festival_industry_specializations_path(@festival), 
                alert: '業界特化設定が見つかりません。'
  end

  def authorize_festival_access
    unless can?(:manage, @festival)
      redirect_to root_path, alert: 'このフェスティバルへのアクセス権限がありません。'
    end
  end

  def industry_specialization_params
    params.require(:industry_specialization).permit(
      :industry_type,
      :specialization_level,
      :certification_required,
      :description,
      :priority,
      compliance_standards: [],
      specialized_features: {},
      industry_regulations: {},
      certification_requirements: [],
      performance_kpis: {},
      vendor_criteria: {}
    )
  end

  def calculate_specialization_stats
    specializations = @festival.industry_specializations
    
    {
      total_count: specializations.count,
      active_count: specializations.active.count,
      completed_count: specializations.completed.count,
      average_progress: specializations.average('specialization_progress') || 0,
      by_industry: specializations.group(:industry_type).count,
      by_status: specializations.group(:status).count,
      requiring_certification: specializations.requiring_certification.count
    }
  end
end