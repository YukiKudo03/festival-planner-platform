require 'rails_helper'

RSpec.describe LineIntegrationsController, type: :controller do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:other_user) { create(:user) }
  let(:other_festival) { create(:festival, user: other_user) }
  let(:other_integration) { create(:line_integration, festival: other_festival, user: other_user) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:active_integration) { create(:line_integration, festival: festival, user: user, is_active: true) }
    let!(:inactive_integration) { create(:line_integration, :inactive, festival: festival, user: user) }

    before do
      get :index
    end

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns user line integrations' do
      expect(assigns(:line_integrations)).to include(active_integration, inactive_integration)
      expect(assigns(:line_integrations)).not_to include(other_integration)
    end

    it 'assigns active integrations' do
      expect(assigns(:active_integrations)).to include(active_integration)
      expect(assigns(:active_integrations)).not_to include(inactive_integration)
    end

    it 'assigns recent activity' do
      expect(assigns(:recent_activity)).to be_present
    end
  end

  describe 'GET #show' do
    let!(:line_group) { create(:line_group, line_integration: line_integration) }
    let!(:line_message) { create(:line_message, line_group: line_group) }

    context 'when user owns the integration' do
      before do
        get :show, params: { id: line_integration.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns line integration' do
        expect(assigns(:line_integration)).to eq(line_integration)
      end

      it 'assigns line groups' do
        expect(assigns(:line_groups)).to include(line_group)
      end

      it 'assigns recent messages' do
        expect(assigns(:recent_messages)).to include(line_message)
      end

      it 'assigns stats' do
        expect(assigns(:stats)).to be_a(Hash)
        expect(assigns(:stats)).to include(:total_groups, :active_groups, :total_messages)
      end
    end

    context 'when user does not own the integration' do
      before do
        get :show, params: { id: other_integration.id }
      end

      it 'redirects with alert' do
        expect(response).to redirect_to(line_integrations_path)
        expect(flash[:alert]).to eq('権限がありません。')
      end
    end
  end

  describe 'GET #new' do
    context 'with festival_id parameter' do
      before do
        get :new, params: { festival_id: festival.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns festival' do
        expect(assigns(:festival)).to eq(festival)
      end

      it 'builds new line integration for festival' do
        expect(assigns(:line_integration)).to be_a_new(LineIntegration)
        expect(assigns(:line_integration).festival).to eq(festival)
      end
    end

    context 'without festival_id parameter' do
      before do
        get :new
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'uses user first festival' do
        expect(assigns(:line_integration).festival).to eq(user.festivals.first)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        line_integration: {
          festival_id: festival.id,
          line_channel_id: '1234567890',
          line_channel_secret: 'secret123',
          line_access_token: 'token123',
          is_active: true
        }
      }
    end

    context 'with valid parameters' do
      it 'creates new line integration' do
        expect {
          post :create, params: valid_params
        }.to change(LineIntegration, :count).by(1)
      end

      it 'assigns festival and user' do
        post :create, params: valid_params
        integration = assigns(:line_integration)
        expect(integration.festival).to eq(festival)
        expect(integration.user).to eq(user)
      end

      it 'redirects to show page with success message' do
        post :create, params: valid_params
        expect(response).to redirect_to(assigns(:line_integration))
        expect(flash[:notice]).to eq('LINE連携が正常に作成されました。')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          line_integration: {
            festival_id: festival.id,
            line_channel_id: '',
            line_channel_secret: '',
            line_access_token: ''
          }
        }
      end

      it 'does not create line integration' do
        expect {
          post :create, params: invalid_params
        }.not_to change(LineIntegration, :count)
      end

      it 'renders new template with unprocessable entity status' do
        post :create, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: line_integration.id,
        line_integration: {
          line_channel_id: 'updated_channel_id',
          is_active: false
        }
      }
    end

    context 'with valid parameters' do
      it 'updates line integration' do
        patch :update, params: update_params
        line_integration.reload
        expect(line_integration.line_channel_id).to eq('updated_channel_id')
        expect(line_integration.is_active).to be false
      end

      it 'redirects to show page with success message' do
        patch :update, params: update_params
        expect(response).to redirect_to(line_integration)
        expect(flash[:notice]).to eq('LINE連携が正常に更新されました。')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          id: line_integration.id,
          line_integration: {
            line_channel_id: ''
          }
        }
      end

      it 'does not update line integration' do
        original_channel_id = line_integration.line_channel_id
        patch :update, params: invalid_update_params
        line_integration.reload
        expect(line_integration.line_channel_id).to eq(original_channel_id)
      end

      it 'renders edit template with unprocessable entity status' do
        patch :update, params: invalid_update_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys line integration' do
      integration_to_delete = create(:line_integration, festival: festival, user: user)
      expect {
        delete :destroy, params: { id: integration_to_delete.id }
      }.to change(LineIntegration, :count).by(-1)
    end

    it 'redirects to index with success message' do
      delete :destroy, params: { id: line_integration.id }
      expect(response).to redirect_to(line_integrations_path)
      expect(flash[:notice]).to eq('LINE連携が削除されました。')
    end
  end

  describe 'POST #authenticate' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
    end

    context 'when authentication succeeds' do
      let(:auth_result) { { success: true, line_user_id: 'U1234567890' } }

      before do
        allow(line_service).to receive(:authenticate_line_account).and_return(auth_result)
      end

      it 'updates integration status' do
        post :authenticate, params: { id: line_integration.id }
        line_integration.reload
        expect(line_integration.status).to eq('active')
        expect(line_integration.is_active).to be true
        expect(line_integration.line_user_id).to eq('U1234567890')
      end

      it 'redirects with success message' do
        post :authenticate, params: { id: line_integration.id }
        expect(response).to redirect_to(line_integration)
        expect(flash[:notice]).to eq('LINE認証が完了しました。')
      end
    end

    context 'when authentication fails' do
      let(:auth_result) { { success: false, error: 'Invalid credentials' } }

      before do
        allow(line_service).to receive(:authenticate_line_account).and_return(auth_result)
      end

      it 'does not update integration status' do
        original_status = line_integration.status
        post :authenticate, params: { id: line_integration.id }
        line_integration.reload
        expect(line_integration.status).to eq(original_status)
      end

      it 'redirects with error message' do
        post :authenticate, params: { id: line_integration.id }
        expect(response).to redirect_to(line_integration)
        expect(flash[:alert]).to include('LINE認証に失敗しました')
      end
    end

    context 'when exception occurs' do
      before do
        allow(line_service).to receive(:authenticate_line_account).and_raise(StandardError, 'Network error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and redirects with alert' do
        expect(Rails.logger).to receive(:error).with(/LINE authentication error/)
        post :authenticate, params: { id: line_integration.id }
        expect(response).to redirect_to(line_integration)
        expect(flash[:alert]).to eq('LINE認証中にエラーが発生しました。')
      end
    end
  end

  describe 'POST #disconnect' do
    before do
      line_integration.update!(status: :active, is_active: true, line_user_id: 'U123', webhook_url: 'https://example.com')
    end

    it 'deactivates integration' do
      post :disconnect, params: { id: line_integration.id }
      line_integration.reload
      expect(line_integration.status).to eq('inactive')
      expect(line_integration.is_active).to be false
      expect(line_integration.line_user_id).to be_nil
      expect(line_integration.webhook_url).to be_nil
    end

    it 'redirects with success message' do
      post :disconnect, params: { id: line_integration.id }
      expect(response).to redirect_to(line_integration)
      expect(flash[:notice]).to eq('LINE連携を無効にしました。')
    end
  end

  describe 'PATCH #update_settings' do
    let(:settings_params) do
      {
        id: line_integration.id,
        line_integration: {
          settings: {
            auto_task_creation: false,
            debug_mode: true
          }
        }
      }
    end

    context 'with valid settings' do
      it 'updates settings and returns success JSON' do
        patch :update_settings, params: settings_params, format: :json
        expect(response).to have_http_status(:success)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('設定が更新されました。')
      end

      it 'updates integration settings' do
        patch :update_settings, params: settings_params, format: :json
        line_integration.reload
        expect(line_integration.settings['auto_task_creation']).to be false
        expect(line_integration.settings['debug_mode']).to be true
      end
    end

    context 'with invalid settings' do
      let(:invalid_settings_params) do
        {
          id: line_integration.id,
          line_integration: {
            line_channel_id: '' # This should trigger validation error
          }
        }
      end

      it 'returns error JSON' do
        patch :update_settings, params: invalid_settings_params, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe 'GET #groups' do
    let!(:line_group) { create(:line_group, line_integration: line_integration) }

    context 'HTML format' do
      before do
        get :groups, params: { id: line_integration.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns line groups' do
        expect(assigns(:line_groups)).to include(line_group)
      end
    end

    context 'JSON format' do
      before do
        get :groups, params: { id: line_integration.id }, format: :json
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns groups as JSON' do
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
      end
    end
  end

  describe 'POST #sync_groups' do
    context 'when sync succeeds' do
      before do
        allow(line_integration).to receive(:sync_groups!).and_return(true)
      end

      it 'redirects with success message' do
        post :sync_groups, params: { id: line_integration.id }
        expect(response).to redirect_to(groups_line_integration_path(line_integration))
        expect(flash[:notice]).to eq('グループ同期が完了しました。')
      end
    end

    context 'when sync fails' do
      before do
        allow(line_integration).to receive(:sync_groups!).and_return(false)
      end

      it 'redirects with error message' do
        post :sync_groups, params: { id: line_integration.id }
        expect(response).to redirect_to(groups_line_integration_path(line_integration))
        expect(flash[:alert]).to eq('グループ同期に失敗しました。')
      end
    end

    context 'when exception occurs' do
      before do
        allow(line_integration).to receive(:sync_groups!).and_raise(StandardError, 'Sync error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and redirects with alert' do
        expect(Rails.logger).to receive(:error).with(/Group sync error/)
        post :sync_groups, params: { id: line_integration.id }
        expect(response).to redirect_to(groups_line_integration_path(line_integration))
        expect(flash[:alert]).to eq('グループ同期中にエラーが発生しました。')
      end
    end
  end

  describe 'POST #test_connection' do
    context 'when connection test succeeds' do
      before do
        allow(line_integration).to receive(:test_connection).and_return(true)
      end

      context 'JSON format' do
        it 'returns success JSON' do
          post :test_connection, params: { id: line_integration.id }, format: :json
          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be true
          expect(json_response['message']).to eq('LINE接続テストが成功しました。')
        end
      end

      context 'HTML format' do
        it 'redirects with success message' do
          post :test_connection, params: { id: line_integration.id }
          expect(response).to redirect_to(line_integration)
          expect(flash[:notice]).to eq('LINE接続テストが成功しました。')
        end
      end
    end

    context 'when connection test fails' do
      before do
        allow(line_integration).to receive(:test_connection).and_return(false)
      end

      context 'JSON format' do
        it 'returns error JSON' do
          post :test_connection, params: { id: line_integration.id }, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['success']).to be false
          expect(json_response['message']).to eq('LINE接続テストに失敗しました。')
        end
      end

      context 'HTML format' do
        it 'redirects with error message' do
          post :test_connection, params: { id: line_integration.id }
          expect(response).to redirect_to(line_integration)
          expect(flash[:alert]).to eq('LINE接続テストに失敗しました。')
        end
      end
    end

    context 'when exception occurs' do
      before do
        allow(line_integration).to receive(:test_connection).and_raise(StandardError, 'Connection error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns error response' do
        expect(Rails.logger).to receive(:error).with(/Connection test error/)

        post :test_connection, params: { id: line_integration.id }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['message']).to eq('テスト中にエラーが発生しました。')
      end
    end
  end

  describe 'POST #callback' do
    let(:webhook_body) do
      {
        events: [
          {
            type: 'message',
            message: {
              id: '123456',
              type: 'text',
              text: 'Hello'
            },
            source: {
              groupId: 'G123',
              userId: 'U123'
            },
            timestamp: Time.current.to_i * 1000
          }
        ]
      }.to_json
    end

    before do
      request.headers['X-Line-Signature'] = 'valid_signature'
      allow(controller).to receive(:verify_webhook_signature).and_return(true)
    end

    context 'with valid webhook data' do
      it 'processes webhook events' do
        expect(LineWebhookProcessorJob).to receive(:perform_later).once

        post :callback, body: webhook_body
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid signature' do
      before do
        allow(controller).to receive(:verify_webhook_signature).and_return(false)
      end

      it 'returns unauthorized status' do
        post :callback, body: webhook_body
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not process events' do
        expect(LineWebhookProcessorJob).not_to receive(:perform_later)
        post :callback, body: webhook_body
      end
    end

    context 'with invalid JSON' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns bad request status' do
        post :callback, body: 'invalid json'
        expect(response).to have_http_status(:bad_request)
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/LINE webhook JSON parse error/)
        post :callback, body: 'invalid json'
      end
    end

    context 'when processing exception occurs' do
      before do
        allow(JSON).to receive(:parse).and_raise(StandardError, 'Processing error')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns internal server error status' do
        post :callback, body: webhook_body
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/LINE webhook processing error/)
        post :callback, body: webhook_body
      end
    end
  end

  describe 'GET #setup_guide' do
    before do
      get :setup_guide
    end

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns integration steps' do
      expect(assigns(:integration_steps)).to be_an(Array)
      expect(assigns(:integration_steps).first).to include(:title, :description, :status)
    end
  end

  describe 'GET #webhook_status' do
    let!(:processed_message) { create(:line_message, :processed, line_group: create(:line_group, line_integration: line_integration)) }
    let!(:failed_message) { create(:line_message, :processing_failed, line_group: create(:line_group, line_integration: line_integration)) }

    before do
      get :webhook_status
    end

    it 'returns http success' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns webhook stats' do
      stats = assigns(:webhook_stats)
      expect(stats).to include(:total_webhooks, :processed_webhooks, :failed_webhooks, :recent_activity)
    end

    it 'assigns recent webhook errors' do
      expect(assigns(:recent_webhook_errors)).to include(failed_message)
    end
  end

  describe 'POST #register_webhook' do
    let(:line_service) { instance_double(LineIntegrationService) }
    let(:webhook_url) { 'https://example.com/line_integrations/callback' }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(controller).to receive(:line_integrations_callback_url).and_return(webhook_url)
    end

    context 'when registration succeeds' do
      before do
        allow(line_service).to receive(:register_webhook).with(webhook_url).and_return({ success: true })
      end

      it 'updates integration webhook URL' do
        post :register_webhook, params: { integration_id: line_integration.id }, format: :json
        line_integration.reload
        expect(line_integration.webhook_url).to eq(webhook_url)
      end

      it 'returns success JSON' do
        post :register_webhook, params: { integration_id: line_integration.id }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['webhook_url']).to eq(webhook_url)
      end
    end

    context 'when registration fails' do
      before do
        allow(line_service).to receive(:register_webhook).and_return({ success: false, error: 'Registration failed' })
      end

      it 'returns error JSON' do
        post :register_webhook, params: { integration_id: line_integration.id }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Registration failed')
      end
    end

    context 'when exception occurs' do
      before do
        allow(line_service).to receive(:register_webhook).and_raise(StandardError, 'Network error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns error JSON' do
        expect(Rails.logger).to receive(:error).with(/Webhook registration error/)

        post :register_webhook, params: { integration_id: line_integration.id }, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Webhook登録中にエラーが発生しました。')
      end
    end
  end

  describe 'authorization' do
    context 'when user is not signed in' do
      before do
        sign_out user
      end

      it 'redirects to sign in page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when accessing other user integration' do
      it 'redirects with authorization error' do
        get :show, params: { id: other_integration.id }
        expect(response).to redirect_to(line_integrations_path)
        expect(flash[:alert]).to eq('権限がありません。')
      end
    end
  end

  describe 'private methods' do
    describe '#calculate_integration_stats' do
      let!(:line_group) { create(:line_group, line_integration: line_integration) }
      let!(:line_message) { create(:line_message, :with_task, line_group: line_group) }

      before do
        controller.instance_variable_set(:@line_integration, line_integration)
      end

      it 'calculates comprehensive stats' do
        stats = controller.send(:calculate_integration_stats)
        expect(stats).to include(
          total_groups: 1,
          active_groups: 1,
          total_messages: 1,
          processed_messages: 1,
          created_tasks: 1,
          webhook_configured: line_integration.webhook_configured?
        )
      end
    end

    describe '#verify_webhook_signature' do
      it 'returns true in non-production environment' do
        allow(Rails.env).to receive(:production?).and_return(false)
        result = controller.send(:verify_webhook_signature, 'body', 'signature')
        expect(result).to be true
      end

      it 'returns true in production environment (placeholder implementation)' do
        allow(Rails.env).to receive(:production?).and_return(true)
        result = controller.send(:verify_webhook_signature, 'body', 'signature')
        expect(result).to be true
      end
    end
  end
end
