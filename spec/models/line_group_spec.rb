require 'rails_helper'

RSpec.describe LineGroup, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }

  describe 'associations' do
    it { should belong_to(:line_integration) }
    it { should have_many(:line_messages).dependent(:destroy) }
    it { should have_one(:festival).through(:line_integration) }
  end

  describe 'validations' do
    subject { build(:line_group, line_integration: line_integration) }
    
    it { should validate_presence_of(:line_group_id) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:line_group_id) }
    it { should validate_uniqueness_of(:line_integration_id).scoped_to(:line_group_id) }
  end

  describe 'serialized attributes' do
    let(:line_group) { create(:line_group, line_integration: line_integration) }

    describe '#group_settings' do
      it 'returns default settings when nil' do
        line_group.update_column(:group_settings, nil)
        expect(line_group.group_settings).to be_a(Hash)
        expect(line_group.group_settings[:task_creation_enabled]).to eq(true)
      end

      it 'persists custom settings' do
        custom_settings = { task_creation_enabled: false, notifications_enabled: false }
        line_group.update!(group_settings: custom_settings)
        line_group.reload
        expect(line_group.group_settings[:task_creation_enabled]).to eq(false)
        expect(line_group.group_settings[:notifications_enabled]).to eq(false)
      end
    end
  end

  describe 'scopes' do
    let!(:active_group) { create(:line_group, line_integration: line_integration, is_active: true) }
    let!(:inactive_group) { create(:line_group, line_integration: line_integration, is_active: false) }
    let!(:recent_group) { create(:line_group, line_integration: line_integration, last_activity_at: 1.hour.ago) }
    let!(:old_group) { create(:line_group, line_integration: line_integration, last_activity_at: 2.days.ago) }

    describe '.active_groups' do
      it 'returns only active groups' do
        expect(LineGroup.active_groups).to include(active_group)
        expect(LineGroup.active_groups).not_to include(inactive_group)
      end
    end

    describe '.recent_activity' do
      it 'returns groups with recent activity' do
        expect(LineGroup.recent_activity).to include(recent_group)
        expect(LineGroup.recent_activity).not_to include(old_group)
      end
    end

    describe '.by_integration' do
      let(:other_integration) { create(:line_integration) }
      let!(:other_group) { create(:line_group, line_integration: other_integration) }

      it 'returns groups for specific integration' do
        groups = LineGroup.by_integration(line_integration)
        expect(groups).to include(active_group, inactive_group)
        expect(groups).not_to include(other_group)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create' do
      it 'sets default group settings' do
        group = create(:line_group, line_integration: line_integration)
        expect(group.group_settings).to be_present
        expect(group.group_settings[:task_creation_enabled]).to eq(true)
      end
    end
  end

  describe 'instance methods' do
    let(:line_group) { create(:line_group, line_integration: line_integration) }

    describe '#active?' do
      it 'returns value of is_active?' do
        line_group.update!(is_active: true)
        expect(line_group.active?).to be true
        
        line_group.update!(is_active: false)
        expect(line_group.active?).to be false
      end
    end

    describe '#recent_messages' do
      let!(:message1) { create(:line_message, line_group: line_group, line_timestamp: 1.hour.ago) }
      let!(:message2) { create(:line_message, line_group: line_group, line_timestamp: 2.hours.ago) }
      let!(:message3) { create(:line_message, line_group: line_group, line_timestamp: 3.hours.ago) }

      it 'returns recent messages in descending order' do
        messages = line_group.recent_messages(2)
        expect(messages).to eq([message1, message2])
      end

      it 'defaults to 50 messages' do
        expect(line_group.recent_messages.limit_value).to eq(50)
      end
    end

    describe '#unprocessed_messages' do
      let!(:processed) { create(:line_message, line_group: line_group, is_processed: true) }
      let!(:unprocessed1) { create(:line_message, line_group: line_group, is_processed: false, line_timestamp: 1.hour.ago) }
      let!(:unprocessed2) { create(:line_message, line_group: line_group, is_processed: false, line_timestamp: 2.hours.ago) }

      it 'returns only unprocessed messages in chronological order' do
        messages = line_group.unprocessed_messages
        expect(messages).to eq([unprocessed2, unprocessed1])
        expect(messages).not_to include(processed)
      end
    end

    describe '#update_activity!' do
      it 'updates last_activity_at with provided timestamp' do
        timestamp = 1.hour.ago
        line_group.update_activity!(timestamp)
        expect(line_group.reload.last_activity_at).to be_within(1.second).of(timestamp)
      end

      it 'defaults to current time' do
        freeze_time do
          line_group.update_activity!
          expect(line_group.reload.last_activity_at).to eq(Time.current)
        end
      end
    end

    describe 'member count methods' do
      describe '#increment_member_count!' do
        it 'increases member count by 1' do
          initial_count = line_group.member_count
          line_group.increment_member_count!
          expect(line_group.reload.member_count).to eq(initial_count + 1)
        end
      end

      describe '#decrement_member_count!' do
        it 'decreases member count by 1' do
          line_group.update!(member_count: 5)
          line_group.decrement_member_count!
          expect(line_group.reload.member_count).to eq(4)
        end

        it 'does not go below 0' do
          line_group.update!(member_count: 0)
          line_group.decrement_member_count!
          expect(line_group.reload.member_count).to eq(0)
        end
      end
    end

    describe 'capability methods' do
      describe '#can_create_tasks?' do
        it 'returns true when active and task creation enabled' do
          line_group.update!(is_active: true, group_settings: { 'task_creation_enabled' => true })
          expect(line_group.can_create_tasks?).to be true
        end

        it 'returns false when not active' do
          line_group.update!(is_active: false, group_settings: { 'task_creation_enabled' => true })
          expect(line_group.can_create_tasks?).to be false
        end

        it 'returns false when task creation disabled' do
          line_group.update!(is_active: true, group_settings: { task_creation_enabled: false })
          expect(line_group.can_create_tasks?).to be false
        end
      end

      describe '#task_creation_enabled?' do
        it 'returns true when setting is true' do
          line_group.update!(group_settings: { task_creation_enabled: true })
          expect(line_group.task_creation_enabled?).to be true
        end

        it 'returns false when setting is false' do
          line_group.update!(group_settings: { task_creation_enabled: false })
          expect(line_group.task_creation_enabled?).to be false
        end
      end

      describe '#notification_enabled?' do
        it 'returns true when setting is true' do
          line_group.update!(group_settings: { notifications_enabled: true })
          expect(line_group.notification_enabled?).to be true
        end

        it 'returns false when setting is false' do
          line_group.update!(group_settings: { notifications_enabled: false })
          expect(line_group.notification_enabled?).to be false
        end
      end

      describe '#auto_parse_enabled?' do
        it 'returns true when setting is true' do
          line_group.update!(group_settings: { auto_parse_enabled: true })
          expect(line_group.auto_parse_enabled?).to be true
        end

        it 'returns false when setting is false' do
          line_group.update!(group_settings: { auto_parse_enabled: false })
          expect(line_group.auto_parse_enabled?).to be false
        end
      end
    end

    describe '#send_message' do
      before do
        line_group.update!(is_active: true)
        allow(line_integration).to receive(:send_notification).and_return(true)
      end

      it 'sends message through line integration when active' do
        expect(line_integration).to receive(:send_notification).with('Hello', line_group.line_group_id)
        result = line_group.send_message('Hello')
        expect(result).to be true
      end

      it 'returns false when not active' do
        line_group.update!(is_active: false)
        result = line_group.send_message('Hello')
        expect(result).to be false
      end
    end

    describe '#process_pending_messages!' do
      let!(:unprocessed1) { create(:line_message, line_group: line_group, is_processed: false) }
      let!(:unprocessed2) { create(:line_message, line_group: line_group, is_processed: false) }
      let!(:processed) { create(:line_message, line_group: line_group, is_processed: true) }

      it 'processes all unprocessed messages' do
        parser1 = instance_double(LineTaskParserService)
        parser2 = instance_double(LineTaskParserService)
        
        expect(LineTaskParserService).to receive(:new).with(unprocessed1).and_return(parser1)
        expect(LineTaskParserService).to receive(:new).with(unprocessed2).and_return(parser2)
        expect(parser1).to receive(:process_message)
        expect(parser2).to receive(:process_message)
        
        line_group.process_pending_messages!
      end
    end

    describe '#stats' do
      let!(:processed_message) { create(:line_message, line_group: line_group, is_processed: true, task: create(:task, festival: festival, user: user)) }
      let!(:unprocessed_message) { create(:line_message, line_group: line_group, is_processed: false) }

      it 'returns comprehensive statistics' do
        line_group.update!(member_count: 10, last_activity_at: 1.hour.ago, is_active: true)
        
        stats = line_group.stats
        expect(stats).to include(
          total_messages: 2,
          processed_messages: 1,
          created_tasks: 1,
          member_count: 10,
          last_activity: line_group.last_activity_at,
          active_status: true
        )
      end
    end
  end

  describe 'private methods' do
    let(:line_group) { build(:line_group, line_integration: line_integration) }

    describe '#default_group_settings' do
      it 'returns hash with expected keys' do
        settings = line_group.send(:default_group_settings)
        expect(settings.keys.map(&:to_s)).to include(
          'task_creation_enabled',
          'notifications_enabled',
          'auto_parse_enabled',
          'require_keywords',
          'allowed_users',
          'restricted_mode',
          'task_assignment_mode',
          'default_task_priority',
          'notification_format',
          'quiet_hours',
          'keywords'
        )
      end

      it 'sets sensible defaults' do
        settings = line_group.send(:default_group_settings)
        expect(settings[:task_creation_enabled]).to be true
        expect(settings[:notifications_enabled]).to be true
        expect(settings[:auto_parse_enabled]).to be true
        expect(settings[:task_assignment_mode]).to eq('auto')
        expect(settings[:default_task_priority]).to eq('medium')
      end
    end
  end
end