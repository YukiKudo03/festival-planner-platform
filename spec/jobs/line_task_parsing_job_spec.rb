require 'rails_helper'

RSpec.describe LineTaskParsingJob, type: :job do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:line_group) { create(:line_group, line_integration: line_integration) }
  let(:line_message) { create(:line_message, line_group: line_group, user: user, message_text: 'タスク: 会場設営をする') }

  describe '#perform' do
    let(:parser_service) { instance_double(LineTaskParserService) }

    before do
      allow(LineTaskParserService).to receive(:new).with(line_message).and_return(parser_service)
    end

    context 'when parsing succeeds' do
      let(:task) { create(:task, festival: festival, user: user) }
      let(:success_result) do
        {
          success: true,
          intent_type: 'task_creation',
          confidence_score: 0.85,
          parsed_content: { 'task_title' => 'Test Task' },
          task: task
        }
      end

      before do
        allow(parser_service).to receive(:process_message).and_return(success_result)
      end

      it 'processes message through parser service' do
        expect(parser_service).to receive(:process_message)
        
        described_class.perform_now(line_message)
      end

      it 'updates message with parsing results' do
        described_class.perform_now(line_message)
        
        line_message.reload
        expect(line_message.is_processed).to be true
        expect(line_message.intent_type).to eq('task_creation')
        expect(line_message.confidence_score).to eq(0.85)
        expect(line_message.task).to eq(task)
      end

      it 'logs successful processing' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Successfully parsed LINE message/)
        
        described_class.perform_now(line_message)
      end

      context 'when task is created' do
        before do
          allow(LineNotificationJob).to receive(:perform_later)
        end

        it 'queues notification job' do
          expect(LineNotificationJob).to receive(:perform_later).with(
            line_integration,
            'task_created',
            hash_including(task_id: task.id)
          )
          
          described_class.perform_now(line_message)
        end
      end

      context 'when no task is created' do
        let(:no_task_result) do
          success_result.merge(task: nil)
        end

        before do
          allow(parser_service).to receive(:process_message).and_return(no_task_result)
          allow(LineNotificationJob).to receive(:perform_later)
        end

        it 'does not queue notification job' do
          expect(LineNotificationJob).not_to receive(:perform_later)
          
          described_class.perform_now(line_message)
        end
      end
    end

    context 'when parsing fails' do
      let(:failure_result) do
        {
          success: false,
          error: 'Could not parse message'
        }
      end

      before do
        allow(parser_service).to receive(:process_message).and_return(failure_result)
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs warning without raising error' do
        expect(Rails.logger).to receive(:warn).with(/Failed to parse LINE message/)
        
        described_class.perform_now(line_message)
      end

      it 'updates message with error information' do
        described_class.perform_now(line_message)
        
        line_message.reload
        expect(line_message.is_processed).to be true
        expect(line_message.processing_errors).not_to be_empty
        expect(line_message.processing_errors.last['message']).to eq('Could not parse message')
      end

      it 'does not create task' do
        expect {
          described_class.perform_now(line_message)
        }.not_to change(Task, :count)
      end
    end

    context 'when message is already processed' do
      before do
        line_message.update!(is_processed: true)
        allow(Rails.logger).to receive(:info)
      end

      it 'skips processing' do
        expect(LineTaskParserService).not_to receive(:new)
        expect(Rails.logger).to receive(:info).with(/LINE message already processed/)
        
        described_class.perform_now(line_message)
      end
    end

    context 'when message cannot create tasks' do
      before do
        allow(line_message).to receive(:can_create_tasks?).and_return(false)
        allow(Rails.logger).to receive(:info)
      end

      it 'skips task creation' do
        expect(Rails.logger).to receive(:info).with(/Message cannot create tasks/)
        
        described_class.perform_now(line_message)
      end

      it 'still processes message for analytics' do
        allow(parser_service).to receive(:process_message).and_return(
          success: true,
          intent_type: 'general_message',
          confidence_score: 0.3,
          parsed_content: {},
          task: nil
        )
        
        described_class.perform_now(line_message)
        
        line_message.reload
        expect(line_message.is_processed).to be true
        expect(line_message.intent_type).to eq('general_message')
      end
    end

    context 'when exception occurs' do
      before do
        allow(parser_service).to receive(:process_message).and_raise(StandardError, 'Unexpected error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and re-raises exception' do
        expect(Rails.logger).to receive(:error).with(/Error processing LINE message/)
        
        expect {
          described_class.perform_now(line_message)
        }.to raise_error(StandardError, 'Unexpected error')
      end

      it 'adds processing error to message' do
        begin
          described_class.perform_now(line_message)
        rescue StandardError
          # Expected to raise
        end
        
        line_message.reload
        expect(line_message.processing_errors).not_to be_empty
        expect(line_message.processing_errors.last['message']).to include('Unexpected error')
      end
    end

    context 'with different message types' do
      context 'with task creation message' do
        let(:line_message) { create(:line_message, line_group: line_group, message_text: 'タスク: 新しい作業') }

        it 'processes task creation' do
          allow(parser_service).to receive(:process_message).and_return(
            success: true,
            intent_type: 'task_creation',
            confidence_score: 0.9,
            parsed_content: { 'task_title' => '新しい作業' },
            task: create(:task, festival: festival)
          )
          
          described_class.perform_now(line_message)
          
          line_message.reload
          expect(line_message.intent_type).to eq('task_creation')
        end
      end

      context 'with task completion message' do
        let(:line_message) { create(:line_message, line_group: line_group, message_text: '作業完了') }

        it 'processes task completion' do
          allow(parser_service).to receive(:process_message).and_return(
            success: true,
            intent_type: 'task_completion',
            confidence_score: 0.8,
            parsed_content: { 'completed_task' => '作業' },
            task: create(:task, festival: festival, status: 'completed')
          )
          
          described_class.perform_now(line_message)
          
          line_message.reload
          expect(line_message.intent_type).to eq('task_completion')
        end
      end

      context 'with status inquiry message' do
        let(:line_message) { create(:line_message, line_group: line_group, message_text: '進捗確認') }

        it 'processes status inquiry' do
          allow(parser_service).to receive(:process_message).and_return(
            success: true,
            intent_type: 'status_inquiry',
            confidence_score: 0.7,
            parsed_content: { 'inquiry_type' => 'general_status' },
            task: nil
          )
          
          described_class.perform_now(line_message)
          
          line_message.reload
          expect(line_message.intent_type).to eq('status_inquiry')
        end
      end
    end

    context 'with confidence score handling' do
      context 'with high confidence' do
        before do
          allow(parser_service).to receive(:process_message).and_return(
            success: true,
            intent_type: 'task_creation',
            confidence_score: 0.9,
            parsed_content: {},
            task: create(:task, festival: festival)
          )
        end

        it 'processes high confidence messages' do
          described_class.perform_now(line_message)
          
          line_message.reload
          expect(line_message.confidence_score).to eq(0.9)
        end
      end

      context 'with low confidence' do
        before do
          allow(parser_service).to receive(:process_message).and_return(
            success: true,
            intent_type: 'general_message',
            confidence_score: 0.2,
            parsed_content: {},
            task: nil
          )
        end

        it 'still processes low confidence messages' do
          described_class.perform_now(line_message)
          
          line_message.reload
          expect(line_message.confidence_score).to eq(0.2)
          expect(line_message.intent_type).to eq('general_message')
        end
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('line_parsing')
    end

    it 'has retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end

    it 'has appropriate wait time for retries' do
      expect(described_class.retry_on[StandardError]).to include(:wait)
    end
  end

  describe 'performance considerations' do
    let(:parser_service) { instance_double(LineTaskParserService) }

    before do
      allow(LineTaskParserService).to receive(:new).with(line_message).and_return(parser_service)
      allow(parser_service).to receive(:process_message).and_return(
        success: true,
        intent_type: 'task_creation',
        confidence_score: 0.8,
        parsed_content: {},
        task: create(:task, festival: festival)
      )
      allow(Rails.logger).to receive(:info)
    end

    it 'logs processing time' do
      expect(Rails.logger).to receive(:info).with(/Successfully parsed LINE message.*in \d+ms/)
      
      described_class.perform_now(line_message)
    end

    context 'with long processing time' do
      before do
        allow(parser_service).to receive(:process_message) do
          sleep(0.1) # Simulate slow processing
          {
            success: true,
            intent_type: 'task_creation',
            confidence_score: 0.8,
            parsed_content: {},
            task: create(:task, festival: festival)
          }
        end
      end

      it 'still completes successfully' do
        expect {
          described_class.perform_now(line_message)
        }.not_to raise_error
      end
    end
  end

  describe 'integration with notification system' do
    let(:parser_service) { instance_double(LineTaskParserService) }
    let(:task) { create(:task, festival: festival, user: user) }

    before do
      allow(LineTaskParserService).to receive(:new).with(line_message).and_return(parser_service)
      allow(LineNotificationJob).to receive(:perform_later)
    end

    context 'when task is assigned to different user' do
      let(:assignee) { create(:user) }
      let(:task) { create(:task, festival: festival, user: assignee) }

      before do
        allow(parser_service).to receive(:process_message).and_return(
          success: true,
          intent_type: 'task_creation',
          confidence_score: 0.9,
          parsed_content: {},
          task: task
        )
      end

      it 'includes assignment information in notification' do
        expect(LineNotificationJob).to receive(:perform_later).with(
          line_integration,
          'task_created',
          hash_including(
            task_id: task.id,
            assigned_to: assignee.id
          )
        )
        
        described_class.perform_now(line_message)
      end
    end

    context 'when task has deadline' do
      let(:task) { create(:task, festival: festival, user: user, due_date: Date.tomorrow) }

      before do
        allow(parser_service).to receive(:process_message).and_return(
          success: true,
          intent_type: 'task_creation',
          confidence_score: 0.9,
          parsed_content: { 'deadline' => Date.tomorrow },
          task: task
        )
      end

      it 'includes deadline information in notification' do
        expect(LineNotificationJob).to receive(:perform_later).with(
          line_integration,
          'task_created',
          hash_including(
            task_id: task.id,
            due_date: Date.tomorrow
          )
        )
        
        described_class.perform_now(line_message)
      end
    end
  end

  describe 'error recovery' do
    let(:parser_service) { instance_double(LineTaskParserService) }

    before do
      allow(LineTaskParserService).to receive(:new).with(line_message).and_return(parser_service)
    end

    context 'when database is temporarily unavailable' do
      before do
        allow(parser_service).to receive(:process_message).and_raise(ActiveRecord::ConnectionTimeoutError)
      end

      it 'allows retry for database connection issues' do
        expect {
          described_class.perform_now(line_message)
        }.to raise_error(ActiveRecord::ConnectionTimeoutError)
      end
    end

    context 'when task validation fails' do
      before do
        allow(parser_service).to receive(:process_message).and_return(
          success: false,
          error: 'Task validation failed: Title cannot be blank'
        )
      end

      it 'handles validation errors gracefully' do
        expect {
          described_class.perform_now(line_message)
        }.not_to raise_error
        
        line_message.reload
        expect(line_message.processing_errors).not_to be_empty
      end
    end
  end
end