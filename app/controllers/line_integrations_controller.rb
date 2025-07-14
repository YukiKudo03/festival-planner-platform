class LineIntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_line_integration, only: [ :show, :edit, :update, :destroy, :authenticate, :disconnect, :update_settings, :groups, :sync_groups, :test_connection ]
  before_action :authorize_line_integration, only: [ :show, :edit, :update, :destroy, :authenticate, :disconnect, :update_settings, :groups, :sync_groups, :test_connection ]

  def index
    @line_integrations = current_user.festivals.includes(:line_integrations).map(&:line_integrations).flatten
    @active_integrations = @line_integrations.select(&:active?)
    @recent_activity = LineMessage.joins(line_group: { line_integration: :festival })
                                  .where(festivals: { user: current_user })
                                  .recent
                                  .limit(10)
  end

  def show
    @line_groups = @line_integration.line_groups.active_groups.includes(:line_messages)
    @recent_messages = @line_integration.line_messages.recent.limit(20)
    @stats = calculate_integration_stats
  end

  def new
    @festival = current_user.festivals.find(params[:festival_id]) if params[:festival_id]
    @line_integration = (@festival || current_user.festivals.first).line_integrations.build
  end

  def create
    @festival = current_user.festivals.find(line_integration_params[:festival_id])
    @line_integration = @festival.line_integrations.build(line_integration_params.merge(user: current_user))

    if @line_integration.save
      redirect_to @line_integration, notice: "LINE連携が正常に作成されました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Render edit form
  end

  def update
    if @line_integration.update(line_integration_params)
      redirect_to @line_integration, notice: "LINE連携が正常に更新されました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @line_integration.destroy
    redirect_to line_integrations_path, notice: "LINE連携が削除されました。"
  end

  # LINE-specific actions
  def authenticate
    begin
      auth_result = LineIntegrationService.new(@line_integration).authenticate_line_account

      if auth_result[:success]
        @line_integration.update!(
          status: :active,
          is_active: true,
          line_user_id: auth_result[:line_user_id]
        )
        redirect_to @line_integration, notice: "LINE認証が完了しました。"
      else
        redirect_to @line_integration, alert: "LINE認証に失敗しました: #{auth_result[:error]}"
      end
    rescue => e
      Rails.logger.error "LINE authentication error: #{e.message}"
      redirect_to @line_integration, alert: "LINE認証中にエラーが発生しました。"
    end
  end

  def disconnect
    @line_integration.update!(
      status: :inactive,
      is_active: false,
      line_user_id: nil,
      webhook_url: nil
    )
    redirect_to @line_integration, notice: "LINE連携を無効にしました。"
  end

  def update_settings
    if @line_integration.update(settings_params)
      render json: { success: true, message: "設定が更新されました。" }
    else
      render json: { success: false, errors: @line_integration.errors.full_messages }
    end
  end

  def groups
    @line_groups = @line_integration.line_groups.includes(:line_messages)

    respond_to do |format|
      format.html
      format.json { render json: @line_groups.as_json(include: [ :line_messages ]) }
    end
  end

  def sync_groups
    begin
      result = @line_integration.sync_groups!

      if result
        redirect_to groups_line_integration_path(@line_integration), notice: "グループ同期が完了しました。"
      else
        redirect_to groups_line_integration_path(@line_integration), alert: "グループ同期に失敗しました。"
      end
    rescue => e
      Rails.logger.error "Group sync error: #{e.message}"
      redirect_to groups_line_integration_path(@line_integration), alert: "グループ同期中にエラーが発生しました。"
    end
  end

  def test_connection
    begin
      result = @line_integration.test_connection

      respond_to do |format|
        format.json do
          if result
            render json: { success: true, message: "LINE接続テストが成功しました。" }
          else
            render json: { success: false, message: "LINE接続テストに失敗しました。" }
          end
        end
        format.html do
          if result
            redirect_to @line_integration, notice: "LINE接続テストが成功しました。"
          else
            redirect_to @line_integration, alert: "LINE接続テストに失敗しました。"
          end
        end
      end
    rescue => e
      Rails.logger.error "Connection test error: #{e.message}"
      respond_to do |format|
        format.json { render json: { success: false, message: "テスト中にエラーが発生しました。" } }
        format.html { redirect_to @line_integration, alert: "テスト中にエラーが発生しました。" }
      end
    end
  end

  # Webhook handling
  def callback
    begin
      body = request.body.read
      signature = request.env["HTTP_X_LINE_SIGNATURE"]

      # Verify webhook signature
      unless verify_webhook_signature(body, signature)
        head :unauthorized
        return
      end

      events = JSON.parse(body)["events"]

      events.each do |event|
        LineWebhookProcessorJob.perform_later(event)
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "LINE webhook JSON parse error: #{e.message}"
      head :bad_request
    rescue => e
      Rails.logger.error "LINE webhook processing error: #{e.message}"
      head :internal_server_error
    end
  end

  def setup_guide
    @integration_steps = [
      {
        title: "LINE Developersでチャネル作成",
        description: "LINE DevelopersコンソールでメッセージングAPIチャネルを作成",
        status: "pending"
      },
      {
        title: "チャネル情報の設定",
        description: "チャネルID、チャネルシークレット、アクセストークンを取得",
        status: "pending"
      },
      {
        title: "Webhook URLの設定",
        description: "LINE DevelopersでWebhook URLを設定",
        status: "pending"
      },
      {
        title: "グループ招待",
        description: "LINEボットを祭りスタッフのグループに招待",
        status: "pending"
      }
    ]
  end

  def webhook_status
    @webhook_stats = {
      total_webhooks: LineMessage.count,
      processed_webhooks: LineMessage.processed.count,
      failed_webhooks: LineMessage.where.not(processing_errors: []).count,
      recent_activity: LineMessage.where("created_at > ?", 24.hours.ago).count
    }

    @recent_webhook_errors = LineMessage.where.not(processing_errors: [])
                                       .order(created_at: :desc)
                                       .limit(10)
  end

  def register_webhook
    integration = LineIntegration.find(params[:integration_id])
    authorize_line_integration_access(integration)

    begin
      webhook_url = line_integrations_callback_url
      result = LineIntegrationService.new(integration).register_webhook(webhook_url)

      if result[:success]
        integration.update!(webhook_url: webhook_url)
        render json: { success: true, webhook_url: webhook_url }
      else
        render json: { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "Webhook registration error: #{e.message}"
      render json: { success: false, error: "Webhook登録中にエラーが発生しました。" }
    end
  end

  private

  def set_line_integration
    @line_integration = LineIntegration.find(params[:id])
  end

  def authorize_line_integration
    authorize_line_integration_access(@line_integration)
  end

  def authorize_line_integration_access(integration)
    unless integration.user == current_user || integration.festival.user == current_user
      redirect_to line_integrations_path, alert: "権限がありません。"
    end
  end

  def line_integration_params
    params.require(:line_integration).permit(
      :festival_id, :line_channel_id, :line_channel_secret, :line_access_token,
      :is_active, settings: {}, notification_preferences: {}
    )
  end

  def settings_params
    params.require(:line_integration).permit(
      settings: [
        :auto_task_creation, :task_reminder_enabled, :group_sync_interval,
        :message_parsing_enabled, :debug_mode, :webhook_signature_verification,
        { allowed_message_types: [], task_keywords: [], priority_keywords: {} }
      ],
      notification_preferences: [
        :task_created, :task_assigned, :task_completed, :task_overdue,
        :deadline_reminder, :festival_updates, :system_notifications,
        :mention_only, :quiet_hours_enabled, { notification_times: {} }
      ]
    )
  end

  def verify_webhook_signature(body, signature)
    return true unless Rails.env.production? # Skip verification in development

    # Implement LINE webhook signature verification
    # This would use the channel secret to verify the webhook signature
    true
  end

  def calculate_integration_stats
    {
      total_groups: @line_integration.line_groups.count,
      active_groups: @line_integration.line_groups.active_groups.count,
      total_messages: @line_integration.line_messages.count,
      processed_messages: @line_integration.line_messages.processed.count,
      created_tasks: @line_integration.line_messages.with_tasks.count,
      last_activity: @line_integration.last_webhook_received_at,
      webhook_configured: @line_integration.webhook_configured?
    }
  end
end
