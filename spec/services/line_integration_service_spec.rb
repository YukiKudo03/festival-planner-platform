require 'rails_helper'

RSpec.describe LineIntegrationService do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:service) { described_class.new(line_integration) }
  let(:mock_client) { instance_double(Line::Bot::Client) }

  before do
    allow(Line::Bot::Client).to receive(:new).and_return(mock_client)
  end

  describe '#initialize' do
    it 'sets integration and builds LINE client' do
      expect(Line::Bot::Client).to receive(:new).and_return(mock_client)
      service = described_class.new(line_integration)
      expect(service.instance_variable_get(:@integration)).to eq(line_integration)
      expect(service.instance_variable_get(:@client)).to eq(mock_client)
    end
  end

  describe '#authenticate_line_account' do
    context 'when line_user_id exists' do
      let(:profile_response) do
        {
          'userId' => 'U1234567890',
          'displayName' => 'Test User',
          'pictureUrl' => 'https://example.com/picture.jpg'
        }
      end

      before do
        line_integration.update!(line_user_id: 'U1234567890')
        allow(mock_client).to receive(:get_profile).with('U1234567890').and_return(profile_response)
      end

      it 'returns success with user profile' do
        result = service.authenticate_line_account
        expect(result[:success]).to be true
        expect(result[:line_user_id]).to eq('U1234567890')
        expect(result[:display_name]).to eq('Test User')
        expect(result[:picture_url]).to eq('https://example.com/picture.jpg')
      end
    end

    context 'when line_user_id does not exist' do
      before do
        line_integration.update!(line_user_id: nil)
        allow(service).to receive(:generate_temp_user_id).and_return('temp_12345678')
      end

      it 'returns success with temporary user ID' do
        result = service.authenticate_line_account
        expect(result[:success]).to be true
        expect(result[:line_user_id]).to eq('temp_12345678')
      end
    end

    context 'when API call fails' do
      before do
        line_integration.update!(line_user_id: 'U1234567890')
        allow(mock_client).to receive(:get_profile).and_raise(StandardError, 'API Error')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns failure with error message' do
        expect(Rails.logger).to receive(:error).with(/LINE authentication failed/)
        result = service.authenticate_line_account
        expect(result[:success]).to be false
        expect(result[:error]).to eq('API Error')
      end
    end
  end

  describe '#test_connection' do
    context 'when connection succeeds' do
      let(:mock_response) { instance_double(Net::HTTPOK) }

      before do
        allow(mock_client).to receive(:get_bot_info).and_return(mock_response)
      end

      it 'returns true' do
        expect(service.test_connection).to be true
      end
    end

    context 'when connection fails' do
      before do
        allow(mock_client).to receive(:get_bot_info).and_raise(StandardError, 'Connection error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns false' do
        expect(Rails.logger).to receive(:error).with(/LINE connection test failed/)
        expect(service.test_connection).to be false
      end
    end
  end

  describe '#sync_groups' do
    context 'when sync succeeds' do
      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'logs info and returns true' do
        expect(Rails.logger).to receive(:info).with(/Group sync initiated/)
        expect(service.sync_groups).to be true
      end
    end

    context 'when sync fails' do
      before do
        allow(Rails.logger).to receive(:info).and_raise(StandardError, 'Sync error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns false' do
        expect(Rails.logger).to receive(:error).with(/Group sync failed/)
        expect(service.sync_groups).to be false
      end
    end
  end

  describe '#send_message' do
    let(:mock_response) { instance_double(Net::HTTPOK) }
    let(:message_text) { 'Hello, test message!' }

    context 'when sending to specific group' do
      let(:group_id) { 'G1234567890' }

      before do
        allow(mock_client).to receive(:push_message).with(group_id, anything).and_return(mock_response)
      end

      it 'sends message to specified group' do
        expect(mock_client).to receive(:push_message).with(
          group_id,
          { type: 'text', text: message_text }
        )
        
        result = service.send_message(message_text, group_id)
        expect(result).to be true
      end
    end

    context 'when sending to all active groups' do
      let!(:line_group1) { create(:line_group, line_integration: line_integration, line_group_id: 'G111') }
      let!(:line_group2) { create(:line_group, line_integration: line_integration, line_group_id: 'G222') }
      let!(:inactive_group) { create(:line_group, :inactive, line_integration: line_integration) }

      before do
        allow(mock_client).to receive(:push_message).and_return(mock_response)
      end

      it 'sends message to all active groups' do
        expect(mock_client).to receive(:push_message).with('G111', anything)
        expect(mock_client).to receive(:push_message).with('G222', anything)
        expect(mock_client).not_to receive(:push_message).with(inactive_group.line_group_id, anything)
        
        result = service.send_message(message_text)
        expect(result).to be true
      end
    end

    context 'when sending fails' do
      let(:group_id) { 'G1234567890' }

      before do
        allow(mock_client).to receive(:push_message).and_raise(StandardError, 'Send error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns false' do
        expect(Rails.logger).to receive(:error).with(/Failed to send LINE message/)
        result = service.send_message(message_text, group_id)
        expect(result).to be false
      end
    end
  end

  describe '#register_webhook' do
    let(:webhook_url) { 'https://example.com/webhook' }

    context 'when registration succeeds' do
      let(:mock_response) { instance_double(Net::HTTPOK) }

      before do
        allow(mock_client).to receive(:set_webhook_endpoint_url).with(webhook_url).and_return(mock_response)
      end

      it 'returns success with webhook URL' do
        result = service.register_webhook(webhook_url)
        expect(result[:success]).to be true
        expect(result[:webhook_url]).to eq(webhook_url)
      end
    end

    context 'when registration fails' do
      let(:mock_response) { instance_double(Net::HTTPBadRequest, body: 'Bad Request') }

      before do
        allow(mock_client).to receive(:set_webhook_endpoint_url).with(webhook_url).and_return(mock_response)
      end

      it 'returns failure with error message' do
        result = service.register_webhook(webhook_url)
        expect(result[:success]).to be false
        expect(result[:error]).to include('Webhook registration failed')
      end
    end

    context 'when exception occurs' do
      before do
        allow(mock_client).to receive(:set_webhook_endpoint_url).and_raise(StandardError, 'Network error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns failure' do
        expect(Rails.logger).to receive(:error).with(/Webhook registration failed/)
        result = service.register_webhook(webhook_url)
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Network error')
      end
    end
  end

  describe '#process_webhook_event' do
    context 'with message event' do
      let(:event) { { 'type' => 'message', 'message' => { 'text' => 'Hello' } } }

      before do
        allow(service).to receive(:process_message_event).with(event)
      end

      it 'processes message event' do
        expect(service).to receive(:process_message_event).with(event)
        service.process_webhook_event(event)
      end
    end

    context 'with join event' do
      let(:event) { { 'type' => 'join' } }

      before do
        allow(service).to receive(:process_join_event).with(event)
      end

      it 'processes join event' do
        expect(service).to receive(:process_join_event).with(event)
        service.process_webhook_event(event)
      end
    end

    context 'with leave event' do
      let(:event) { { 'type' => 'leave' } }

      before do
        allow(service).to receive(:process_leave_event).with(event)
      end

      it 'processes leave event' do
        expect(service).to receive(:process_leave_event).with(event)
        service.process_webhook_event(event)
      end
    end

    context 'with memberJoined event' do
      let(:event) { { 'type' => 'memberJoined' } }

      before do
        allow(service).to receive(:process_member_joined_event).with(event)
      end

      it 'processes member joined event' do
        expect(service).to receive(:process_member_joined_event).with(event)
        service.process_webhook_event(event)
      end
    end

    context 'with memberLeft event' do
      let(:event) { { 'type' => 'memberLeft' } }

      before do
        allow(service).to receive(:process_member_left_event).with(event)
      end

      it 'processes member left event' do
        expect(service).to receive(:process_member_left_event).with(event)
        service.process_webhook_event(event)
      end
    end

    context 'with unhandled event type' do
      let(:event) { { 'type' => 'unknown_event' } }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'logs unhandled event' do
        expect(Rails.logger).to receive(:info).with(/Unhandled LINE event type: unknown_event/)
        service.process_webhook_event(event)
      end
    end
  end

  describe '#get_group_info' do
    let(:group_id) { 'G1234567890' }

    context 'when API call succeeds' do
      let(:mock_response) { instance_double(Net::HTTPOK, body: '{"groupName":"Test Group"}') }

      before do
        allow(mock_client).to receive(:get_group_summary).with(group_id).and_return(mock_response)
      end

      it 'returns parsed group info' do
        result = service.get_group_info(group_id)
        expect(result).to eq({ 'groupName' => 'Test Group' })
      end
    end

    context 'when API call fails' do
      let(:mock_response) { instance_double(Net::HTTPNotFound) }

      before do
        allow(mock_client).to receive(:get_group_summary).with(group_id).and_return(mock_response)
      end

      it 'returns nil' do
        result = service.get_group_info(group_id)
        expect(result).to be_nil
      end
    end

    context 'when exception occurs' do
      before do
        allow(mock_client).to receive(:get_group_summary).and_raise(StandardError, 'API error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Failed to get group info/)
        result = service.get_group_info(group_id)
        expect(result).to be_nil
      end
    end
  end

  describe '#get_group_member_count' do
    let(:group_id) { 'G1234567890' }

    context 'when API call succeeds' do
      let(:mock_response) { instance_double(Net::HTTPOK, body: '{"count":5}') }

      before do
        allow(mock_client).to receive(:get_group_members_count).with(group_id).and_return(mock_response)
      end

      it 'returns member count' do
        result = service.get_group_member_count(group_id)
        expect(result).to eq(5)
      end
    end

    context 'when API call fails' do
      let(:mock_response) { instance_double(Net::HTTPNotFound) }

      before do
        allow(mock_client).to receive(:get_group_members_count).with(group_id).and_return(mock_response)
      end

      it 'returns 0' do
        result = service.get_group_member_count(group_id)
        expect(result).to eq(0)
      end
    end

    context 'when exception occurs' do
      before do
        allow(mock_client).to receive(:get_group_members_count).and_raise(StandardError, 'API error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and returns 0' do
        expect(Rails.logger).to receive(:error).with(/Failed to get group member count/)
        result = service.get_group_member_count(group_id)
        expect(result).to eq(0)
      end
    end
  end

  describe 'private methods' do
    describe '#process_message_event' do
      let(:event) do
        {
          'type' => 'message',
          'message' => {
            'id' => 'msg123',
            'type' => 'text',
            'text' => 'Test message'
          },
          'source' => {
            'type' => 'group',
            'groupId' => 'G123',
            'userId' => 'U123'
          },
          'timestamp' => (Time.current.to_f * 1000).to_i
        }
      end

      let(:line_group) { create(:line_group, line_integration: line_integration, line_group_id: 'G123') }

      before do
        allow(service).to receive(:find_or_create_group).with('G123').and_return(line_group)
        allow(service).to receive(:find_user_by_line_id).with('U123').and_return(user)
        allow(LineTaskParsingJob).to receive(:perform_later)
      end

      context 'when processing succeeds' do
        it 'creates line message' do
          expect {
            service.send(:process_message_event, event)
          }.to change(LineMessage, :count).by(1)
        end

        it 'updates group activity' do
          expect(line_group).to receive(:update_activity!)
          service.send(:process_message_event, event)
        end

        it 'queues task parsing job when auto parse enabled' do
          line_group.update!(group_settings: { 'auto_parse_enabled' => true })
          expect(LineTaskParsingJob).to receive(:perform_later)
          service.send(:process_message_event, event)
        end

        it 'does not queue job when auto parse disabled' do
          line_group.update!(group_settings: { 'auto_parse_enabled' => false })
          expect(LineTaskParsingJob).not_to receive(:perform_later)
          service.send(:process_message_event, event)
        end
      end

      context 'when not a group message' do
        before do
          event['source']['type'] = 'user'
        end

        it 'returns early without processing' do
          expect(service).not_to receive(:find_or_create_group)
          result = service.send(:process_message_event, event)
          expect(result).to be_nil
        end
      end

      context 'when exception occurs' do
        before do
          allow(service).to receive(:find_or_create_group).and_raise(StandardError, 'Processing error')
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error and returns nil' do
          expect(Rails.logger).to receive(:error).with(/Failed to process message event/)
          result = service.send(:process_message_event, event)
          expect(result).to be_nil
        end
      end
    end

    describe '#process_join_event' do
      let(:event) do
        {
          'type' => 'join',
          'source' => {
            'type' => 'group',
            'groupId' => 'G123'
          }
        }
      end

      let(:line_group) { create(:line_group, line_integration: line_integration, line_group_id: 'G123') }

      before do
        allow(service).to receive(:find_or_create_group).with('G123').and_return(line_group)
        allow(service).to receive(:build_welcome_message).and_return('Welcome!')
        allow(service).to receive(:send_message)
        allow(service).to receive(:update_group_info)
      end

      it 'sends welcome message' do
        expect(service).to receive(:send_message).with('Welcome!', 'G123')
        service.send(:process_join_event, event)
      end

      it 'updates group info' do
        expect(service).to receive(:update_group_info).with(line_group)
        service.send(:process_join_event, event)
      end

      context 'when not a group event' do
        before do
          event['source']['type'] = 'user'
        end

        it 'returns early without processing' do
          expect(service).not_to receive(:find_or_create_group)
          service.send(:process_join_event, event)
        end
      end
    end

    describe '#process_leave_event' do
      let(:event) do
        {
          'type' => 'leave',
          'source' => {
            'type' => 'group',
            'groupId' => 'G123'
          }
        }
      end

      let!(:line_group) { create(:line_group, line_integration: line_integration, line_group_id: 'G123', is_active: true) }

      it 'deactivates group' do
        service.send(:process_leave_event, event)
        line_group.reload
        expect(line_group.is_active).to be false
      end

      context 'when group not found' do
        before do
          line_group.destroy
        end

        it 'does nothing' do
          expect { service.send(:process_leave_event, event) }.not_to raise_error
        end
      end
    end

    describe '#find_or_create_group' do
      let(:group_id) { 'G1234567890' }

      context 'when group exists' do
        let!(:existing_group) { create(:line_group, line_integration: line_integration, line_group_id: group_id) }

        it 'returns existing group' do
          result = service.send(:find_or_create_group, group_id)
          expect(result).to eq(existing_group)
        end
      end

      context 'when group does not exist' do
        let(:group_info) { { 'groupName' => 'New Group' } }

        before do
          allow(service).to receive(:get_group_info).with(group_id).and_return(group_info)
          allow(service).to receive(:get_group_member_count).with(group_id).and_return(5)
        end

        it 'creates new group with fetched info' do
          expect {
            result = service.send(:find_or_create_group, group_id)
            expect(result.line_group_id).to eq(group_id)
            expect(result.name).to eq('New Group')
            expect(result.member_count).to eq(5)
          }.to change(LineGroup, :count).by(1)
        end
      end

      context 'when group creation fails' do
        before do
          allow(service).to receive(:get_group_info).and_raise(StandardError, 'Creation error')
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error and returns nil' do
          expect(Rails.logger).to receive(:error).with(/Failed to find or create group/)
          result = service.send(:find_or_create_group, group_id)
          expect(result).to be_nil
        end
      end
    end

    describe '#find_user_by_line_id' do
      it 'returns integration user as fallback' do
        result = service.send(:find_user_by_line_id, 'U123')
        expect(result).to eq(line_integration.user)
      end
    end

    describe '#build_welcome_message' do
      it 'builds welcome message with festival name' do
        message = service.send(:build_welcome_message)
        expect(message).to include(festival.name)
        expect(message).to include('LINE連携が開始されました')
        expect(message).to include('タスクの登録方法')
      end
    end

    describe '#generate_temp_user_id' do
      it 'generates temporary user ID' do
        allow(SecureRandom).to receive(:hex).with(8).and_return('abcdef12')
        result = service.send(:generate_temp_user_id)
        expect(result).to eq('temp_abcdef12')
      end
    end

    describe '#build_line_client' do
      it 'builds LINE client with integration credentials' do
        expect(Line::Bot::Client).to receive(:new) do |&block|
          config = double('config')
          expect(config).to receive(:channel_id=).with(line_integration.line_channel_id)
          expect(config).to receive(:channel_secret=).with(line_integration.line_channel_secret)
          expect(config).to receive(:channel_token=).with(line_integration.line_access_token)
          block.call(config)
          mock_client
        end

        service.send(:build_line_client)
      end
    end
  end
end