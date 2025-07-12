# frozen_string_literal: true

class TourismCollaborationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_festival
  before_action :set_tourism_collaboration, only: [:show, :edit, :update, :destroy, :activate, :complete, :approve, :cancel]
  before_action :authorize_festival_access

  def index
    @tourism_collaborations = @festival.tourism_collaborations.includes(:tourism_board, :coordinator)
    @collaboration_stats = calculate_collaboration_stats
    @available_tourism_boards = MunicipalAuthority.where(authority_type: 'tourism_board')
  end

  def show
    @economic_impact = @tourism_collaboration.economic_impact_estimate
    @visitor_impact = @tourism_collaboration.visitor_impact_estimate
    @roi = @tourism_collaboration.return_on_investment
    @target_demographics = @tourism_collaboration.target_demographic_summary
    @marketing_effectiveness = @tourism_collaboration.marketing_channel_effectiveness
  end

  def new
    @tourism_collaboration = @festival.tourism_collaborations.build
    @available_tourism_boards = MunicipalAuthority.where(authority_type: 'tourism_board')
    @collaboration_types = TourismCollaboration::COLLABORATION_TYPES
    @coordinators = User.where(role: ['admin', 'committee_member'])
  end

  def create
    @tourism_collaboration = @festival.tourism_collaborations.build(tourism_collaboration_params)
    @tourism_collaboration.coordinator = current_user
    
    if @tourism_collaboration.save
      redirect_to [@festival, @tourism_collaboration], 
                  notice: '観光連携が正常に作成されました。'
    else
      @available_tourism_boards = MunicipalAuthority.where(authority_type: 'tourism_board')
      @collaboration_types = TourismCollaboration::COLLABORATION_TYPES
      @coordinators = User.where(role: ['admin', 'committee_member'])
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_tourism_boards = MunicipalAuthority.where(authority_type: 'tourism_board')
    @collaboration_types = TourismCollaboration::COLLABORATION_TYPES
    @coordinators = User.where(role: ['admin', 'committee_member'])
  end

  def update
    if @tourism_collaboration.update(tourism_collaboration_params)
      redirect_to [@festival, @tourism_collaboration], 
                  notice: '観光連携が正常に更新されました。'
    else
      @available_tourism_boards = MunicipalAuthority.where(authority_type: 'tourism_board')
      @collaboration_types = TourismCollaboration::COLLABORATION_TYPES
      @coordinators = User.where(role: ['admin', 'committee_member'])
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tourism_collaboration.destroy
    redirect_to festival_tourism_collaborations_path(@festival), 
                notice: '観光連携が削除されました。'
  end

  def activate
    if @tourism_collaboration.activate!
      redirect_to [@festival, @tourism_collaboration], 
                  notice: '観光連携が有効化されました。'
    else
      redirect_to [@festival, @tourism_collaboration], 
                  alert: '有効化に必要な承認が得られていません。'
    end
  end

  def approve
    approval_notes = params[:approval_notes]
    
    if @tourism_collaboration.approve!(approved_by: current_user.id, notes: approval_notes)
      redirect_to [@festival, @tourism_collaboration], 
                  notice: '観光連携が承認されました。'
    else
      redirect_to [@festival, @tourism_collaboration], 
                  alert: '承認処理でエラーが発生しました。'
    end
  end

  def complete
    completion_notes = params[:completion_notes]
    
    if @tourism_collaboration.complete!(completion_notes: completion_notes)
      redirect_to [@festival, @tourism_collaboration], 
                  notice: '観光連携プログラムが完了しました。'
    else
      redirect_to [@festival, @tourism_collaboration], 
                  alert: '完了処理でエラーが発生しました。'
    end
  end

  def cancel
    cancellation_reason = params[:cancellation_reason]
    
    if @tourism_collaboration.cancel!(reason: cancellation_reason, cancelled_by: current_user.id)
      redirect_to [@festival, @tourism_collaboration], 
                  notice: '観光連携がキャンセルされました。'
    else
      redirect_to [@festival, @tourism_collaboration], 
                  alert: 'キャンセル処理でエラーが発生しました。'
    end
  end

  def update_visitor_analytics
    @tourism_collaboration = @festival.tourism_collaborations.find(params[:id])
    analytics_data = params[:analytics] || {}
    
    begin
      @tourism_collaboration.update_visitor_analytics(analytics_data)
      render json: { 
        status: 'success', 
        message: '来訪者分析データが更新されました',
        updated_data: @tourism_collaboration.visitor_data
      }
    rescue => e
      render json: { 
        status: 'error', 
        message: "更新エラー: #{e.message}" 
      }, status: :unprocessable_entity
    end
  end

  def collaboration_dashboard
    @tourism_collaboration = @festival.tourism_collaborations.find(params[:id])
    @recent_activities = @tourism_collaboration.tourism_activities.recent.limit(10)
    @marketing_campaigns = @tourism_collaboration.marketing_campaigns.active
    @visitor_analytics = @tourism_collaboration.visitor_analytics.recent.limit(5)
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          collaboration: @tourism_collaboration.summary,
          recent_activities: @recent_activities,
          marketing_campaigns: @marketing_campaigns,
          visitor_analytics: @visitor_analytics
        }
      }
    end
  end

  def export_report
    @tourism_collaboration = @festival.tourism_collaborations.find(params[:id])
    
    respond_to do |format|
      format.csv do
        csv_data = generate_collaboration_csv(@tourism_collaboration)
        send_data csv_data, 
                  filename: "tourism_collaboration_#{@tourism_collaboration.collaboration_number}.csv",
                  type: 'text/csv'
      end
      format.pdf do
        pdf_data = generate_collaboration_pdf(@tourism_collaboration)
        send_data pdf_data, 
                  filename: "tourism_collaboration_#{@tourism_collaboration.collaboration_number}.pdf",
                  type: 'application/pdf'
      end
    end
  end

  private

  def set_festival
    @festival = current_user.festivals.find(params[:festival_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to festivals_path, alert: 'フェスティバルが見つかりません。'
  end

  def set_tourism_collaboration
    @tourism_collaboration = @festival.tourism_collaborations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to festival_tourism_collaborations_path(@festival), 
                alert: '観光連携が見つかりません。'
  end

  def authorize_festival_access
    unless can?(:manage, @festival)
      redirect_to root_path, alert: 'このフェスティバルへのアクセス権限がありません。'
    end
  end

  def tourism_collaboration_params
    params.require(:tourism_collaboration).permit(
      :collaboration_type,
      :tourism_board_id,
      :coordinator_id,
      :start_date,
      :end_date,
      :budget_allocation,
      :expected_visitors,
      :priority,
      :description,
      marketing_objectives: [],
      target_demographics: {},
      promotional_channels: [],
      collaboration_benefits: {},
      performance_metrics: {}
    )
  end

  def calculate_collaboration_stats
    collaborations = @festival.tourism_collaborations
    
    {
      total_count: collaborations.count,
      active_count: collaborations.active.count,
      completed_count: collaborations.completed.count,
      total_budget: collaborations.sum(:budget_allocation),
      total_expected_visitors: collaborations.sum(:expected_visitors),
      average_roi: collaborations.completed.average('return_on_investment'),
      by_type: collaborations.group(:collaboration_type).count,
      by_status: collaborations.group(:status).count,
      requiring_attention: collaborations.requiring_attention.count
    }
  end

  def generate_collaboration_csv(collaboration)
    # CSV generation logic would go here
    # For now, return basic information
    CSV.generate(headers: true) do |csv|
      csv << ['項目', '値']
      csv << ['連携番号', collaboration.collaboration_number]
      csv << ['連携タイプ', collaboration.collaboration_type_name]
      csv << ['観光局', collaboration.tourism_board.name]
      csv << ['期間', "#{collaboration.start_date} - #{collaboration.end_date}"]
      csv << ['予算配分', "¥#{collaboration.budget_allocation.to_s(:delimited)}"]
      csv << ['期待来訪者数', collaboration.expected_visitors]
      csv << ['経済効果予測', "¥#{collaboration.economic_impact_estimate.to_s(:delimited)}"]
      csv << ['ROI', "#{collaboration.return_on_investment}%"]
    end
  end

  def generate_collaboration_pdf(collaboration)
    # PDF generation logic would go here
    # For now, return placeholder
    "PDF report for collaboration #{collaboration.collaboration_number}"
  end
end