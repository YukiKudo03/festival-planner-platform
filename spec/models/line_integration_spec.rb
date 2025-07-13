require 'rails_helper'

RSpec.describe LineIntegration, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  
  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:user) }
    it { should have_many(:line_groups).dependent(:destroy) }
    it { should have_many(:line_messages).through(:line_groups) }
  end

  describe 'validations' do
    subject { build(:line_integration, festival: festival, user: user) }
    
    it { should validate_presence_of(:line_channel_id) }
    it { should validate_presence_of(:line_channel_secret) }
    it { should validate_presence_of(:line_access_token) }
    it { should validate_uniqueness_of(:line_channel_id) }
    it { should validate_uniqueness_of(:festival_id).scoped_to(:user_id) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(inactive: 0, active: 1, error: 2, suspended: 3) }
  end

  describe 'scopes' do
    let!(:active_integration) { create(:line_integration, festival: festival, user: user, is_active: true, status: :active) }
    let!(:inactive_integration) { create(:line_integration, is_active: false, status: :inactive) }
    let!(:recent_integration) { create(:line_integration, last_webhook_received_at: 30.minutes.ago) }
    let!(:old_integration) { create(:line_integration, last_webhook_received_at: 2.hours.ago) }

    describe '.active_integrations' do
      it 'returns only active integrations' do
        expect(LineIntegration.active_integrations).to include(active_integration)
        expect(LineIntegration.active_integrations).not_to include(inactive_integration)
      end
    end

    describe '.for_festival' do
      it 'returns integrations for specific festival' do
        expect(LineIntegration.for_festival(festival)).to include(active_integration)
        expect(LineIntegration.for_festival(festival)).not_to include(inactive_integration)
      end
    end

    describe '.recent_activity' do
      it 'returns integrations with recent webhook activity' do
        expect(LineIntegration.recent_activity).to include(recent_integration)
        expect(LineIntegration.recent_activity).not_to include(old_integration)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'sets default settings' do
        integration = create(:line_integration, festival: festival, user: user)
        expect(integration.settings).to be_present
        expect(integration.settings['auto_task_creation']).to eq(true)
      end

      it 'initializes webhook' do
        expect(LineWebhookSetupJob).to receive(:perform_later)
        create(:line_integration, festival: festival, user: user)
      end
    end
  end

  describe 'serialized attributes' do
    let(:integration) { create(:line_integration, festival: festival, user: user) }

    describe '#settings' do
      it 'returns default settings when nil' do
        integration.update_column(:settings, nil)
        expect(integration.settings).to be_a(Hash)
        expect(integration.settings['auto_task_creation']).to eq(true)
      end

      it 'persists custom settings' do
        custom_settings = { auto_task_creation: false, debug_mode: true }
        integration.update!(settings: custom_settings)
        integration.reload
        expect(integration.settings['auto_task_creation']).to eq(false)
        expect(integration.settings['debug_mode']).to eq(true)
      end
    end

    describe '#notification_preferences' do
      it 'returns default preferences when nil' do
        integration.update_column(:notification_preferences, nil)
        expect(integration.notification_preferences).to be_a(Hash)
        expect(integration.notification_preferences['task_created']).to eq(true)
      end
    end
  end

  describe 'instance methods' do
    let(:integration) { create(:line_integration, festival: festival, user: user) }

    describe '#active?' do
      it 'returns true when is_active and status is active' do
        integration.update!(is_active: true, status: :active)
        expect(integration.active?).to be true
      end

      it 'returns false when is_active is false' do
        integration.update!(is_active: false, status: :active)
        expect(integration.active?).to be false
      end

      it 'returns false when status is not active' do
        integration.update!(is_active: true, status: :error)
        expect(integration.active?).to be false
      end
    end

    describe '#can_send_notifications?' do
      it 'returns true when active and has access token' do
        integration.update!(is_active: true, status: :active, line_access_token: 'token')
        expect(integration.can_send_notifications?).to be true
      end

      it 'returns false when not active' do
        integration.update!(is_active: false, line_access_token: 'token')
        expect(integration.can_send_notifications?).to be false
      end

      it 'returns false when no access token' do
        integration.update!(is_active: true, status: :active, line_access_token: nil)
        expect(integration.can_send_notifications?).to be false
      end
    end

    describe '#webhook_configured?' do
      it 'returns true when webhook_url is present' do
        integration.update!(webhook_url: 'https://example.com/webhook')
        expect(integration.webhook_configured?).to be true
      end

      it 'returns false when webhook_url is blank' do
        integration.update!(webhook_url: nil)
        expect(integration.webhook_configured?).to be false
      end
    end

    describe '#sync_groups!' do
      let(:service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegrationService).to receive(:new).with(integration).and_return(service)
        integration.update!(is_active: true, status: :active)
      end

      it 'calls LineIntegrationService to sync groups' do
        expect(service).to receive(:sync_groups).and_return(true)
        result = integration.sync_groups!
        expect(result).to be true
        expect(integration.reload.last_sync_at).to be_present
      end

      it 'handles service errors and sets error status' do
        expect(service).to receive(:sync_groups).and_raise(StandardError, 'API Error')
        expect(Rails.logger).to receive(:error).with(/Failed to sync LINE groups/)
        
        result = integration.sync_groups!
        expect(result).to be false
        expect(integration.reload.status).to eq('error')
      end

      it 'returns false when not active' do
        integration.update!(is_active: false)
        result = integration.sync_groups!
        expect(result).to be false
      end
    end

    describe '#test_connection' do
      let(:service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegrationService).to receive(:new).with(integration).and_return(service)
      end

      it 'returns true when connection is successful' do
        expect(service).to receive(:test_connection).and_return(true)
        expect(integration.test_connection).to be true
      end

      it 'handles connection errors' do
        expect(service).to receive(:test_connection).and_raise(StandardError, 'Connection failed')
        expect(Rails.logger).to receive(:error).with(/LINE connection test failed/)
        expect(integration.test_connection).to be false
      end

      it 'returns false when no access token' do
        integration.update!(line_access_token: nil)
        expect(integration.test_connection).to be false
      end
    end

    describe '#send_notification' do
      let(:service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegrationService).to receive(:new).with(integration).and_return(service)
        integration.update!(is_active: true, status: :active, line_access_token: 'token')
      end

      it 'sends message through service' do
        expect(service).to receive(:send_message).with('Hello', 'group123').and_return(true)
        result = integration.send_notification('Hello', 'group123')
        expect(result).to be true
      end

      it 'sends to all groups when no group_id specified' do
        expect(service).to receive(:send_message).with('Hello', nil).and_return(true)
        result = integration.send_notification('Hello')
        expect(result).to be true
      end

      it 'handles sending errors' do
        expect(service).to receive(:send_message).and_raise(StandardError, 'Send failed')
        expect(Rails.logger).to receive(:error).with(/Failed to send LINE notification/)
        result = integration.send_notification('Hello')
        expect(result).to be false
      end
    end

    describe '#update_activity!' do
      it 'updates last_webhook_received_at timestamp' do
        freeze_time do
          integration.update_activity!
          expect(integration.reload.last_webhook_received_at).to eq(Time.current)
        end
      end
    end

    describe 'encryption methods' do
      let(:integration) { create(:line_integration, festival: festival, user: user, line_access_token: 'secret_token') }

      describe '#encrypted_access_token' do
        it 'returns encrypted token' do
          encrypted = integration.encrypted_access_token
          expect(encrypted).to be_present
          expect(encrypted).not_to eq('secret_token')
        end

        it 'returns nil when no token' do
          integration.update!(line_access_token: nil)
          expect(integration.encrypted_access_token).to be_nil
        end
      end

      describe '#decrypt_access_token' do
        it 'decrypts encrypted token' do
          encrypted = integration.encrypted_access_token
          decrypted = integration.decrypt_access_token(encrypted)
          expect(decrypted).to eq('secret_token')
        end

        it 'returns nil when no encrypted token' do
          expect(integration.decrypt_access_token(nil)).to be_nil
        end
      end
    end
  end

  describe 'private methods' do
    let(:integration) { build(:line_integration, festival: festival, user: user) }

    describe '#default_settings' do
      it 'returns hash with expected keys' do
        settings = integration.send(:default_settings)
        expect(settings).to include(
          'auto_task_creation',
          'task_reminder_enabled',
          'group_sync_interval',
          'message_parsing_enabled',
          'debug_mode',
          'webhook_signature_verification',
          'allowed_message_types',
          'task_keywords',
          'priority_keywords'
        )
      end

      it 'sets debug_mode based on environment' do
        allow(Rails.env).to receive(:development?).and_return(false)
        settings = integration.send(:default_settings)
        expect(settings['debug_mode']).to be false
      end
    end

    describe '#default_notification_preferences' do
      it 'returns hash with notification settings' do
        prefs = integration.send(:default_notification_preferences)
        expect(prefs).to include(
          'task_created',
          'task_assigned', 
          'task_completed',
          'task_overdue',
          'deadline_reminder',
          'festival_updates',
          'system_notifications',
          'notification_times',
          'quiet_hours_enabled',
          'mention_only'
        )
      end
    end
  end
end