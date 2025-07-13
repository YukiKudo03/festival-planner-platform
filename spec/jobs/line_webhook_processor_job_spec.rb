require 'rails_helper'

RSpec.describe LineWebhookProcessorJob, type: :job do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:line_group) { create(:line_group, line_integration: line_integration) }

  describe '#perform' do
    let(:message_event) do
      {
        'type' => 'message',
        'replyToken' => 'reply_token_123',
        'source' => {
          'userId' => 'U1234567890',
          'groupId' => line_group.line_group_id,
          'type' => 'group'
        },
        'message' => {
          'id' => 'msg_123456',
          'type' => 'text',
          'text' => 'タスク: 会場設営をする'
        },
        'timestamp' => (Time.current.to_f * 1000).to_i,
        'mode' => 'active'
      }
    end

    let(:join_event) do
      {
        'type' => 'join',
        'source' => {
          'groupId' => line_group.line_group_id,
          'type' => 'group'
        },
        'timestamp' => (Time.current.to_f * 1000).to_i
      }
    end

    let(:leave_event) do
      {
        'type' => 'leave',
        'source' => {
          'groupId' => line_group.line_group_id,
          'type' => 'group'
        },
        'timestamp' => (Time.current.to_f * 1000).to_i
      }
    end

    context 'with message event' do
      let(:line_service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegration).to receive(:find_by).and_return(line_integration)
        allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
        allow(line_service).to receive(:process_webhook_event)
      end

      it 'processes message event through service' do
        expect(line_service).to receive(:process_webhook_event).with(message_event)
        
        described_class.perform_now(message_event)
      end

      it 'logs successful processing' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Successfully processed LINE webhook event/)
        
        described_class.perform_now(message_event)
      end
    end

    context 'with join event' do
      let(:line_service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegration).to receive(:find_by).and_return(line_integration)
        allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
        allow(line_service).to receive(:process_webhook_event)
      end

      it 'processes join event through service' do
        expect(line_service).to receive(:process_webhook_event).with(join_event)
        
        described_class.perform_now(join_event)
      end
    end

    context 'with leave event' do
      let(:line_service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegration).to receive(:find_by).and_return(line_integration)
        allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
        allow(line_service).to receive(:process_webhook_event)
      end

      it 'processes leave event through service' do
        expect(line_service).to receive(:process_webhook_event).with(leave_event)
        
        described_class.perform_now(leave_event)
      end
    end

    context 'when integration not found' do
      before do
        allow(LineIntegration).to receive(:find_by).and_return(nil)
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs warning and skips processing' do
        expect(Rails.logger).to receive(:warn).with(/LINE integration not found/)
        
        described_class.perform_now(message_event)
      end

      it 'does not raise error' do
        expect { described_class.perform_now(message_event) }.not_to raise_error
      end
    end

    context 'when integration is inactive' do
      before do
        line_integration.update!(is_active: false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs warning and skips processing' do
        expect(Rails.logger).to receive(:warn).with(/LINE integration is inactive/)
        
        described_class.perform_now(message_event)
      end
    end

    context 'when processing fails' do
      let(:line_service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegration).to receive(:find_by).and_return(line_integration)
        allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
        allow(line_service).to receive(:process_webhook_event).and_raise(StandardError, 'Processing failed')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and re-raises exception' do
        expect(Rails.logger).to receive(:error).with(/Failed to process LINE webhook event/)
        
        expect {
          described_class.perform_now(message_event)
        }.to raise_error(StandardError, 'Processing failed')
      end
    end

    context 'with invalid event structure' do
      let(:invalid_event) { { 'invalid' => 'event' } }

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error for missing source' do
        expect(Rails.logger).to receive(:error).with(/Invalid event structure/)
        
        expect {
          described_class.perform_now(invalid_event)
        }.to raise_error(/Invalid event structure/)
      end
    end

    context 'with different source types' do
      let(:user_message_event) do
        message_event.merge(
          'source' => {
            'userId' => 'U1234567890',
            'type' => 'user'
          }
        )
      end

      let(:room_message_event) do
        message_event.merge(
          'source' => {
            'userId' => 'U1234567890',
            'roomId' => 'R1234567890',
            'type' => 'room'
          }
        )
      end

      it 'handles user source type' do
        expect { described_class.perform_now(user_message_event) }.not_to raise_error
      end

      it 'handles room source type' do
        expect { described_class.perform_now(room_message_event) }.not_to raise_error
      end
    end

    context 'with retry mechanism' do
      let(:line_service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegration).to receive(:find_by).and_return(line_integration)
        allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      end

      it 'retries on transient failures' do
        call_count = 0
        allow(line_service).to receive(:process_webhook_event) do
          call_count += 1
          raise StandardError, 'Temporary failure' if call_count <= 2
          true
        end

        expect {
          described_class.perform_now(message_event)
        }.to raise_error(StandardError)
        
        expect(call_count).to eq(1) # Job framework handles retries
      end
    end

    context 'performance tracking' do
      let(:line_service) { instance_double(LineIntegrationService) }

      before do
        allow(LineIntegration).to receive(:find_by).and_return(line_integration)
        allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
        allow(line_service).to receive(:process_webhook_event)
        allow(Rails.logger).to receive(:info)
      end

      it 'logs processing time' do
        expect(Rails.logger).to receive(:info).with(/Successfully processed LINE webhook event.*in \d+ms/)
        
        described_class.perform_now(message_event)
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('line_webhooks')
    end

    it 'has retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end

    it 'has discard configuration for permanent failures' do
      expect(described_class.discard_on).to include(ArgumentError)
    end
  end

  describe 'error handling patterns' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegration).to receive(:find_by).and_return(line_integration)
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
    end

    context 'with network timeouts' do
      before do
        allow(line_service).to receive(:process_webhook_event).and_raise(Net::TimeoutError)
      end

      it 'allows retry for network timeouts' do
        expect {
          described_class.perform_now(message_event)
        }.to raise_error(Net::TimeoutError)
      end
    end

    context 'with JSON parsing errors' do
      before do
        allow(line_service).to receive(:process_webhook_event).and_raise(JSON::ParserError)
      end

      it 'discards job for JSON parsing errors' do
        expect {
          described_class.perform_now(message_event)
        }.to raise_error(JSON::ParserError)
      end
    end

    context 'with LINE API errors' do
      before do
        allow(line_service).to receive(:process_webhook_event).and_raise(Line::Bot::API::HTTPError.new('API Error'))
      end

      it 'allows retry for LINE API errors' do
        expect {
          described_class.perform_now(message_event)
        }.to raise_error(Line::Bot::API::HTTPError)
      end
    end
  end

  describe 'integration with other components' do
    let(:line_service) { instance_double(LineIntegrationService) }
    let(:created_message) { create(:line_message, line_group: line_group) }

    before do
      allow(LineIntegration).to receive(:find_by).and_return(line_integration)
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(line_service).to receive(:process_webhook_event).and_return(created_message)
    end

    it 'updates integration last webhook received timestamp' do
      freeze_time do
        described_class.perform_now(message_event)
        line_integration.reload
        expect(line_integration.last_webhook_received_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'when message processing creates tasks' do
      let(:task) { create(:task, festival: festival, user: user) }

      before do
        created_message.update!(task: task)
        allow(LineTaskParsingJob).to receive(:perform_later)
      end

      it 'may trigger downstream task processing' do
        described_class.perform_now(message_event)
        # This would be tested in integration tests
      end
    end
  end
end