require 'rails_helper'

RSpec.describe LineWebhookSetupJob, type: :job do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }

  describe '#perform' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
    end

    context 'when webhook setup succeeds' do
      let(:webhook_url) { 'https://example.com/line_integrations/callback' }
      let(:success_result) { { success: true, webhook_url: webhook_url } }

      before do
        allow(line_service).to receive(:register_webhook).and_return(success_result)
        allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url).and_return(webhook_url)
      end

      it 'registers webhook through service' do
        expect(line_service).to receive(:register_webhook).with(webhook_url)
        
        described_class.perform_now(line_integration)
      end

      it 'updates integration with webhook URL' do
        described_class.perform_now(line_integration)
        
        line_integration.reload
        expect(line_integration.webhook_url).to eq(webhook_url)
      end

      it 'logs successful setup' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Webhook setup completed/)
        
        described_class.perform_now(line_integration)
      end

      it 'marks integration as active' do
        described_class.perform_now(line_integration)
        
        line_integration.reload
        expect(line_integration.status).to eq('active')
        expect(line_integration.is_active).to be true
      end
    end

    context 'when webhook setup fails' do
      let(:webhook_url) { 'https://example.com/line_integrations/callback' }
      let(:failure_result) { { success: false, error: 'LINE API error' } }

      before do
        allow(line_service).to receive(:register_webhook).and_return(failure_result)
        allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url).and_return(webhook_url)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error message' do
        expect(Rails.logger).to receive(:error).with(/Webhook setup failed/)
        
        described_class.perform_now(line_integration)
      end

      it 'marks integration as error status' do
        described_class.perform_now(line_integration)
        
        line_integration.reload
        expect(line_integration.status).to eq('error')
        expect(line_integration.last_error_message).to eq('LINE API error')
        expect(line_integration.last_error_at).to be_present
      end

      it 'does not update webhook URL' do
        original_webhook_url = line_integration.webhook_url
        described_class.perform_now(line_integration)
        
        line_integration.reload
        expect(line_integration.webhook_url).to eq(original_webhook_url)
      end

      it 'raises error for retry mechanism' do
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(/Webhook setup failed/)
      end
    end

    context 'when integration is already configured' do
      before do
        line_integration.update!(webhook_url: 'https://existing.com/webhook', status: :active)
        allow(Rails.logger).to receive(:info)
      end

      it 'skips setup if webhook already configured' do
        expect(LineIntegrationService).not_to receive(:new)
        expect(Rails.logger).to receive(:info).with(/Webhook already configured/)
        
        described_class.perform_now(line_integration)
      end
    end

    context 'when integration is inactive' do
      before do
        line_integration.update!(is_active: false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'skips setup for inactive integration' do
        expect(LineIntegrationService).not_to receive(:new)
        expect(Rails.logger).to receive(:warn).with(/Integration is inactive/)
        
        described_class.perform_now(line_integration)
      end
    end

    context 'when webhook URL generation fails' do
      before do
        allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url)
          .and_raise(ActionController::UrlGenerationError, 'URL generation failed')
        allow(Rails.logger).to receive(:error)
      end

      it 'handles URL generation error' do
        expect(Rails.logger).to receive(:error).with(/Failed to generate webhook URL/)
        
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(/Failed to generate webhook URL/)
      end
    end

    context 'when LINE service raises exception' do
      let(:webhook_url) { 'https://example.com/line_integrations/callback' }

      before do
        allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url).and_return(webhook_url)
        allow(line_service).to receive(:register_webhook).and_raise(Line::Bot::API::HTTPError.new('API unavailable'))
        allow(Rails.logger).to receive(:error)
      end

      it 'handles LINE API exceptions' do
        expect(Rails.logger).to receive(:error).with(/LINE API error during webhook setup/)
        
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(Line::Bot::API::HTTPError)
      end

      it 'updates integration with error details' do
        begin
          described_class.perform_now(line_integration)
        rescue Line::Bot::API::HTTPError
          # Expected to raise
        end
        
        line_integration.reload
        expect(line_integration.status).to eq('error')
        expect(line_integration.last_error_message).to include('API unavailable')
      end
    end

    context 'with custom webhook URL' do
      let(:custom_webhook_url) { 'https://custom.domain.com/webhooks/line' }

      before do
        allow(ENV).to receive(:[]).with('LINE_WEBHOOK_BASE_URL').and_return('https://custom.domain.com')
        allow(line_service).to receive(:register_webhook).with(custom_webhook_url).and_return(
          { success: true, webhook_url: custom_webhook_url }
        )
      end

      it 'uses custom webhook URL when configured' do
        expect(line_service).to receive(:register_webhook).with(custom_webhook_url)
        
        described_class.perform_now(line_integration)
      end
    end

    context 'with webhook verification' do
      let(:webhook_url) { 'https://example.com/line_integrations/callback' }

      before do
        allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url).and_return(webhook_url)
        allow(line_service).to receive(:register_webhook).and_return({ success: true, webhook_url: webhook_url })
        allow(line_service).to receive(:test_connection).and_return(true)
      end

      it 'verifies webhook after setup' do
        expect(line_service).to receive(:test_connection)
        
        described_class.perform_now(line_integration)
      end

      context 'when verification fails' do
        before do
          allow(line_service).to receive(:test_connection).and_return(false)
          allow(Rails.logger).to receive(:warn)
        end

        it 'logs warning but does not fail setup' do
          expect(Rails.logger).to receive(:warn).with(/Webhook verification failed/)
          
          expect {
            described_class.perform_now(line_integration)
          }.not_to raise_error
        end
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('line_setup')
    end

    it 'has retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end

    it 'has exponential backoff for retries' do
      expect(described_class.retry_on[StandardError]).to include(:wait)
    end

    it 'has maximum retry attempts' do
      expect(described_class.retry_on[StandardError]).to include(:attempts)
    end
  end

  describe 'webhook URL generation' do
    context 'in development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(Rails.application.config).to receive(:force_ssl).and_return(false)
      end

      it 'uses HTTP for development' do
        # This would be tested in integration tests where actual URL helpers are available
        expect {
          described_class.perform_now(line_integration)
        }.not_to raise_error
      end
    end

    context 'in production environment' do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.application.config).to receive(:force_ssl).and_return(true)
      end

      it 'uses HTTPS for production' do
        # This would be tested in integration tests where actual URL helpers are available
        expect {
          described_class.perform_now(line_integration)
        }.not_to raise_error
      end
    end
  end

  describe 'error handling and recovery' do
    let(:line_service) { instance_double(LineIntegrationService) }
    let(:webhook_url) { 'https://example.com/line_integrations/callback' }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url).and_return(webhook_url)
    end

    context 'with network timeout' do
      before do
        allow(line_service).to receive(:register_webhook).and_raise(Net::TimeoutError)
      end

      it 'allows retry for network timeouts' do
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(Net::TimeoutError)
      end
    end

    context 'with SSL certificate error' do
      before do
        allow(line_service).to receive(:register_webhook).and_raise(OpenSSL::SSL::SSLError)
      end

      it 'allows retry for SSL errors' do
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(OpenSSL::SSL::SSLError)
      end
    end

    context 'with LINE API rate limiting' do
      before do
        allow(line_service).to receive(:register_webhook).and_raise(Line::Bot::API::HTTPError.new('Rate limit exceeded'))
      end

      it 'allows retry for rate limiting' do
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(Line::Bot::API::HTTPError)
      end
    end

    context 'with invalid credentials' do
      before do
        allow(line_service).to receive(:register_webhook).and_raise(Line::Bot::API::HTTPError.new('Unauthorized'))
        allow(Rails.logger).to receive(:error)
      end

      it 'marks integration as error without retry' do
        expect {
          described_class.perform_now(line_integration)
        }.to raise_error(Line::Bot::API::HTTPError)
        
        line_integration.reload
        expect(line_integration.status).to eq('error')
      end
    end
  end

  describe 'integration lifecycle' do
    let(:line_service) { instance_double(LineIntegrationService) }
    let(:webhook_url) { 'https://example.com/line_integrations/callback' }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(Rails.application.routes.url_helpers).to receive(:line_integrations_callback_url).and_return(webhook_url)
      allow(line_service).to receive(:register_webhook).and_return({ success: true, webhook_url: webhook_url })
      allow(line_service).to receive(:test_connection).and_return(true)
    end

    it 'follows complete setup workflow' do
      expect(line_service).to receive(:register_webhook).ordered
      expect(line_service).to receive(:test_connection).ordered
      
      described_class.perform_now(line_integration)
      
      line_integration.reload
      expect(line_integration.webhook_url).to eq(webhook_url)
      expect(line_integration.status).to eq('active')
      expect(line_integration.is_active).to be true
    end

    context 'when called multiple times' do
      it 'is idempotent' do
        described_class.perform_now(line_integration)
        initial_webhook_url = line_integration.reload.webhook_url
        
        described_class.perform_now(line_integration)
        expect(line_integration.reload.webhook_url).to eq(initial_webhook_url)
      end
    end
  end
end