require 'rails_helper'

RSpec.describe LineMessage, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:line_group) { create(:line_group, line_integration: line_integration) }

  describe 'associations' do
    it { should belong_to(:line_group) }
    it { should belong_to(:user).optional }
    it { should belong_to(:task).optional }
    it { should have_one(:line_integration).through(:line_group) }
    it { should have_one(:festival).through(:line_integration) }
  end

  describe 'validations' do
    subject { build(:line_message, line_group: line_group) }
    
    it { should validate_presence_of(:line_message_id) }
    it { should validate_presence_of(:message_text) }
    it { should validate_presence_of(:message_type) }
    it { should validate_uniqueness_of(:line_message_id) }
  end

  describe 'enums' do
    it { should define_enum_for(:intent_type).with_values(
      unknown: 'unknown',
      task_creation: 'task_creation',
      task_update: 'task_update',
      task_completion: 'task_completion',
      task_assignment: 'task_assignment',
      status_inquiry: 'status_inquiry',
      reminder_request: 'reminder_request',
      general_message: 'general_message'
    ).with_default('unknown') }
  end

  describe 'scopes' do
    let!(:processed_message) { create(:line_message, line_group: line_group, is_processed: true) }
    let!(:unprocessed_message) { create(:line_message, line_group: line_group, is_processed: false) }
    let!(:message_with_task) { create(:line_message, :with_task, line_group: line_group) }
    let!(:high_confidence_message) { create(:line_message, line_group: line_group, confidence_score: 0.8) }
    let!(:low_confidence_message) { create(:line_message, line_group: line_group, confidence_score: 0.5) }

    describe '.unprocessed' do
      it 'returns only unprocessed messages' do
        expect(LineMessage.unprocessed).to include(unprocessed_message)
        expect(LineMessage.unprocessed).not_to include(processed_message)
      end
    end

    describe '.processed' do
      it 'returns only processed messages' do
        expect(LineMessage.processed).to include(processed_message)
        expect(LineMessage.processed).not_to include(unprocessed_message)
      end
    end

    describe '.with_tasks' do
      it 'returns messages with associated tasks' do
        expect(LineMessage.with_tasks).to include(message_with_task)
        expect(LineMessage.with_tasks).not_to include(unprocessed_message)
      end
    end

    describe '.by_intent' do
      let!(:task_creation_message) { create(:line_message, line_group: line_group, intent_type: 'task_creation') }
      
      it 'returns messages with specific intent type' do
        expect(LineMessage.by_intent('task_creation')).to include(task_creation_message)
        expect(LineMessage.by_intent('task_creation')).not_to include(unprocessed_message)
      end
    end

    describe '.high_confidence' do
      it 'returns messages with confidence score >= 0.7' do
        expect(LineMessage.high_confidence).to include(high_confidence_message)
        expect(LineMessage.high_confidence).not_to include(low_confidence_message)
      end
    end

    describe '.recent' do
      it 'orders messages by line_timestamp descending' do
        recent_messages = LineMessage.recent.limit(2)
        expect(recent_messages.first.line_timestamp).to be >= recent_messages.second.line_timestamp
      end
    end
  end

  describe 'serialized attributes' do
    let(:line_message) { create(:line_message, line_group: line_group) }

    describe '#parsed_content' do
      it 'returns empty hash when nil' do
        line_message.update_column(:parsed_content, nil)
        expect(line_message.parsed_content).to eq({})
      end

      it 'persists hash data' do
        content = { 'task_title' => 'Test Task', 'priority' => 'high' }
        line_message.update!(parsed_content: content)
        line_message.reload
        expect(line_message.parsed_content['task_title']).to eq('Test Task')
      end
    end

    describe '#processing_errors' do
      it 'returns empty array when nil' do
        line_message.update_column(:processing_errors, nil)
        expect(line_message.processing_errors).to eq([])
      end

      it 'persists array data' do
        errors = [{ 'message' => 'Parse error', 'timestamp' => Time.current.iso8601 }]
        line_message.update!(processing_errors: errors)
        line_message.reload
        expect(line_message.processing_errors.first['message']).to eq('Parse error')
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save :set_default_timestamp' do
      it 'sets line_timestamp when nil' do
        freeze_time do
          message = build(:line_message, line_group: line_group, line_timestamp: nil)
          message.save!
          expect(message.line_timestamp).to eq(Time.current)
        end
      end

      it 'does not override existing timestamp' do
        timestamp = 1.hour.ago
        message = build(:line_message, line_group: line_group, line_timestamp: timestamp)
        message.save!
        expect(message.line_timestamp).to eq(timestamp)
      end
    end
  end

  describe 'instance methods' do
    let(:line_message) { create(:line_message, line_group: line_group) }

    describe '#processed?' do
      it 'returns true when is_processed is true' do
        line_message.update!(is_processed: true)
        expect(line_message.processed?).to be true
      end

      it 'returns false when is_processed is false' do
        line_message.update!(is_processed: false)
        expect(line_message.processed?).to be false
      end
    end

    describe '#has_task?' do
      it 'returns true when task is present' do
        task = create(:task, festival: festival, user: user)
        line_message.update!(task: task)
        expect(line_message.has_task?).to be true
      end

      it 'returns false when task is nil' do
        line_message.update!(task: nil)
        expect(line_message.has_task?).to be false
      end
    end

    describe '#high_confidence?' do
      it 'returns true when confidence_score >= 0.7' do
        line_message.update!(confidence_score: 0.8)
        expect(line_message.high_confidence?).to be true
      end

      it 'returns false when confidence_score < 0.7' do
        line_message.update!(confidence_score: 0.5)
        expect(line_message.high_confidence?).to be false
      end

      it 'returns false when confidence_score is nil' do
        line_message.update!(confidence_score: nil)
        expect(line_message.high_confidence?).to be false
      end
    end

    describe '#can_create_task?' do
      let(:active_group) { create(:line_group, line_integration: line_integration, is_active: true) }
      let(:message) { create(:line_message, line_group: active_group, is_processed: false, intent_type: 'task_creation', confidence_score: 0.8) }

      it 'returns true when all conditions are met' do
        expect(message.can_create_task?).to be true
      end

      it 'returns false when already processed' do
        message.update!(is_processed: true)
        expect(message.can_create_task?).to be false
      end

      it 'returns false when group cannot create tasks' do
        active_group.update!(is_active: false)
        expect(message.can_create_task?).to be false
      end

      it 'returns false when intent_type is not task creation related' do
        message.update!(intent_type: 'general_message')
        expect(message.can_create_task?).to be false
      end

      it 'returns false when confidence is low' do
        message.update!(confidence_score: 0.5)
        expect(message.can_create_task?).to be false
      end
    end

    describe '#sender_name' do
      it 'returns sender_display_name when present' do
        line_message.update!(sender_display_name: 'Test User')
        expect(line_message.sender_name).to eq('Test User')
      end

      it 'returns user display_name when sender_display_name is blank' do
        line_message.update!(sender_display_name: nil, user: user)
        expect(line_message.sender_name).to eq(user.display_name)
      end

      it 'returns "Unknown User" when both are blank' do
        line_message.update!(sender_display_name: nil, user: nil)
        expect(line_message.sender_name).to eq('Unknown User')
      end
    end

    describe '#process_message!' do
      let(:parser_service) { instance_double(LineTaskParserService) }
      
      before do
        allow(LineTaskParserService).to receive(:new).with(line_message).and_return(parser_service)
      end

      context 'when processing succeeds' do
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
          allow(line_message).to receive(:send_confirmation_message)
        end

        it 'updates message with parsing results' do
          expect(line_message.process_message!).to be true
          line_message.reload
          expect(line_message.is_processed).to be true
          expect(line_message.intent_type).to eq('task_creation')
          expect(line_message.confidence_score).to eq(0.85)
          expect(line_message.task).to eq(task)
        end

        it 'sends confirmation message when task is created' do
          expect(line_message).to receive(:send_confirmation_message)
          line_message.process_message!
        end
      end

      context 'when processing fails' do
        let(:failure_result) do
          {
            success: false,
            error: 'Failed to parse message'
          }
        end

        before do
          allow(parser_service).to receive(:process_message).and_return(failure_result)
        end

        it 'adds processing error and returns false' do
          expect(line_message.process_message!).to be false
          expect(line_message.processing_errors).not_to be_empty
        end
      end

      context 'when already processed' do
        before do
          line_message.update!(is_processed: true)
        end

        it 'returns false without processing' do
          expect(LineTaskParserService).not_to receive(:new)
          expect(line_message.process_message!).to be false
        end
      end

      context 'when exception occurs' do
        before do
          allow(parser_service).to receive(:process_message).and_raise(StandardError, 'Processing error')
        end

        it 'handles exception and logs error' do
          expect(Rails.logger).to receive(:error).with(/Failed to process LINE message/)
          expect(line_message.process_message!).to be false
        end
      end
    end

    describe '#retry_processing!' do
      before do
        line_message.update!(
          is_processed: false,
          processing_errors: [{ 'message' => 'Previous error' }],
          confidence_score: 0.5,
          intent_type: 'general_message'
        )
      end

      it 'clears previous processing data and retries' do
        allow(line_message).to receive(:process_message!).and_return(true)
        
        expect(line_message.retry_processing!).to be true
        line_message.reload
        expect(line_message.processing_errors).to be_empty
        expect(line_message.confidence_score).to be_nil
        expect(line_message.intent_type).to eq('unknown')
      end

      it 'returns false when already processed' do
        line_message.update!(is_processed: true)
        expect(line_message.retry_processing!).to be false
      end
    end

    describe '#add_processing_error' do
      it 'adds error message with timestamp' do
        freeze_time do
          line_message.add_processing_error('Test error')
          line_message.reload
          
          error = line_message.processing_errors.last
          expect(error['message']).to eq('Test error')
          expect(error['timestamp']).to eq(Time.current.iso8601)
        end
      end

      it 'appends to existing errors' do
        line_message.update!(processing_errors: [{ 'message' => 'First error' }])
        line_message.add_processing_error('Second error')
        line_message.reload
        
        expect(line_message.processing_errors.size).to eq(2)
        expect(line_message.processing_errors.last['message']).to eq('Second error')
      end
    end

    describe '#send_confirmation_message' do
      let(:task) { create(:task, festival: festival, user: user, title: 'Test Task') }
      
      before do
        line_message.update!(task: task, intent_type: 'task_creation')
        allow(line_group).to receive(:notification_enabled?).and_return(true)
        allow(line_group).to receive(:send_message)
      end

      it 'sends confirmation when has task and notifications enabled' do
        expect(line_group).to receive(:send_message).with(/タスクを作成しました/)
        line_message.send_confirmation_message
      end

      it 'does not send when no task' do
        line_message.update!(task: nil)
        expect(line_group).not_to receive(:send_message)
        line_message.send_confirmation_message
      end

      it 'does not send when notifications disabled' do
        allow(line_group).to receive(:notification_enabled?).and_return(false)
        expect(line_group).not_to receive(:send_message)
        line_message.send_confirmation_message
      end
    end

    describe '#extract_mentions' do
      it 'extracts @mentions from message text' do
        line_message.update!(message_text: 'Hello @user1 and @user2, please check this')
        expect(line_message.extract_mentions).to match_array(['user1', 'user2'])
      end

      it 'returns empty array when no mentions' do
        line_message.update!(message_text: 'Hello everyone')
        expect(line_message.extract_mentions).to be_empty
      end

      it 'returns empty array when message_text is nil' do
        line_message.update!(message_text: nil)
        expect(line_message.extract_mentions).to be_empty
      end
    end

    describe '#mentioned_users' do
      let!(:user1) { create(:user, first_name: 'John', last_name: 'Doe') }
      let!(:user2) { create(:user, email: 'jane@example.com') }

      it 'finds users by name mentions' do
        line_message.update!(message_text: 'Hello @John, please help')
        mentioned = line_message.mentioned_users
        expect(mentioned).to include(user1)
      end

      it 'finds users by email mentions' do
        line_message.update!(message_text: 'Hey @jane, check this out')
        mentioned = line_message.mentioned_users
        expect(mentioned).to include(user2)
      end

      it 'returns empty array when no matching users' do
        line_message.update!(message_text: 'Hello @nonexistent')
        expect(line_message.mentioned_users).to be_empty
      end
    end

    describe '#notification_data' do
      let(:task) { create(:task, festival: festival, user: user, title: 'Test Task') }
      
      before do
        line_message.update!(
          task: task,
          intent_type: 'task_creation',
          confidence_score: 0.8,
          sender_display_name: 'Test Sender',
          message_text: 'This is a test message for notification'
        )
      end

      it 'returns comprehensive notification data' do
        data = line_message.notification_data
        
        expect(data).to include(
          id: line_message.id,
          line_message_id: line_message.line_message_id,
          sender: 'Test Sender',
          group_name: line_group.name,
          intent_type: 'task_creation',
          confidence_score: 0.8,
          has_task: true,
          task_title: 'Test Task'
        )
        expect(data[:message_preview]).to include('This is a test message')
      end
    end
  end

  describe 'private methods' do
    let(:line_message) { build(:line_message, line_group: line_group, intent_type: 'task_creation') }
    let(:task) { create(:task, festival: festival, user: user, title: 'Test Task', due_date: Date.tomorrow) }

    before do
      line_message.task = task
    end

    describe '#build_confirmation_message' do
      it 'builds task creation confirmation' do
        line_message.intent_type = 'task_creation'
        message = line_message.send(:build_confirmation_message)
        expect(message).to include('タスクを作成しました')
        expect(message).to include('Test Task')
      end

      it 'builds task completion confirmation' do
        line_message.intent_type = 'task_completion'
        message = line_message.send(:build_confirmation_message)
        expect(message).to include('タスクが完了しました')
        expect(message).to include('Test Task')
      end

      it 'builds task assignment confirmation' do
        line_message.intent_type = 'task_assignment'
        message = line_message.send(:build_confirmation_message)
        expect(message).to include('タスクが割り当てられました')
        expect(message).to include('Test Task')
      end

      it 'builds default confirmation for other types' do
        line_message.intent_type = 'general_message'
        message = line_message.send(:build_confirmation_message)
        expect(message).to include('メッセージを処理しました')
      end
    end
  end
end