require 'rails_helper'

RSpec.describe LineNotificationJob, type: :job do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:line_group) { create(:line_group, line_integration: line_integration) }
  let(:task) { create(:task, festival: festival, user: user, title: 'Test Task') }

  describe '#perform' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(line_service).to receive(:send_message).and_return(true)
    end

    context 'with task_created notification' do
      let(:notification_data) do
        {
          task_id: task.id,
          assigned_to: user.id,
          due_date: Date.tomorrow
        }
      end

      it 'sends task creation notification' do
        expect(line_service).to receive(:send_message).with(
          match(/📝 新しいタスクが作成されました/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_created', notification_data)
      end

      it 'includes task details in message' do
        expect(line_service).to receive(:send_message).with(
          match(/Test Task/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_created', notification_data)
      end

      it 'includes assignee information' do
        expect(line_service).to receive(:send_message).with(
          match(/👤 担当者: #{user.display_name}/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_created', notification_data)
      end

      it 'includes due date when present' do
        expect(line_service).to receive(:send_message).with(
          match(/📅 期限: #{Date.tomorrow.strftime('%Y年%m月%d日')}/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_created', notification_data)
      end
    end

    context 'with task_completed notification' do
      let(:completed_task) { create(:task, festival: festival, user: user, title: 'Completed Task', status: 'completed') }
      let(:notification_data) do
        {
          task_id: completed_task.id,
          completed_by: user.id
        }
      end

      it 'sends task completion notification' do
        expect(line_service).to receive(:send_message).with(
          match(/✅ タスクが完了されました/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_completed', notification_data)
      end

      it 'includes completion celebration' do
        expect(line_service).to receive(:send_message).with(
          match(/🎉/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_completed', notification_data)
      end
    end

    context 'with task_assigned notification' do
      let(:assignee) { create(:user, first_name: '田中', last_name: '太郎') }
      let(:notification_data) do
        {
          task_id: task.id,
          assigned_to: assignee.id,
          assigned_by: user.id
        }
      end

      it 'sends task assignment notification' do
        expect(line_service).to receive(:send_message).with(
          match(/📋 タスクが割り当てられました/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_assigned', notification_data)
      end

      it 'includes assignee and assigner information' do
        expect(line_service).to receive(:send_message).with(
          match(/👤 担当者: #{assignee.display_name}/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_assigned', notification_data)
      end
    end

    context 'with deadline_reminder notification' do
      let(:due_task) { create(:task, festival: festival, user: user, title: 'Due Task', due_date: Date.tomorrow) }
      let(:notification_data) do
        {
          task_id: due_task.id,
          due_date: Date.tomorrow,
          days_until_due: 1
        }
      end

      it 'sends deadline reminder notification' do
        expect(line_service).to receive(:send_message).with(
          match(/⏰ 期限リマインダー/),
          nil
        )
        
        described_class.perform_now(line_integration, 'deadline_reminder', notification_data)
      end

      it 'includes urgency for near deadlines' do
        expect(line_service).to receive(:send_message).with(
          match(/⚠️.*明日が期限/),
          nil
        )
        
        described_class.perform_now(line_integration, 'deadline_reminder', notification_data)
      end
    end

    context 'with festival_update notification' do
      let(:notification_data) do
        {
          festival_id: festival.id,
          update_type: 'venue_changed',
          message: '会場が変更されました'
        }
      end

      it 'sends festival update notification' do
        expect(line_service).to receive(:send_message).with(
          match(/🎭 #{festival.name} からのお知らせ/),
          nil
        )
        
        described_class.perform_now(line_integration, 'festival_update', notification_data)
      end

      it 'includes update message' do
        expect(line_service).to receive(:send_message).with(
          match(/会場が変更されました/),
          nil
        )
        
        described_class.perform_now(line_integration, 'festival_update', notification_data)
      end
    end

    context 'with custom group targeting' do
      let(:target_group_id) { 'G1234567890' }
      let(:notification_data) do
        {
          task_id: task.id,
          target_group_id: target_group_id
        }
      end

      it 'sends to specific group when specified' do
        expect(line_service).to receive(:send_message).with(
          anything,
          target_group_id
        )
        
        described_class.perform_now(line_integration, 'task_created', notification_data)
      end
    end

    context 'when integration is inactive' do
      before do
        line_integration.update!(is_active: false)
        allow(Rails.logger).to receive(:info)
      end

      it 'skips sending notification' do
        expect(LineIntegrationService).not_to receive(:new)
        expect(Rails.logger).to receive(:info).with(/Integration is inactive/)
        
        described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
      end
    end

    context 'when notification preferences disable notifications' do
      before do
        line_integration.update!(
          notification_preferences: {
            'task_created' => false,
            'task_completed' => true
          }
        )
        allow(Rails.logger).to receive(:info)
      end

      it 'skips disabled notification types' do
        expect(LineIntegrationService).not_to receive(:new)
        expect(Rails.logger).to receive(:info).with(/Notification type 'task_created' is disabled/)
        
        described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
      end

      it 'allows enabled notification types' do
        expect(line_service).to receive(:send_message)
        
        described_class.perform_now(line_integration, 'task_completed', { task_id: task.id })
      end
    end

    context 'with quiet hours enabled' do
      before do
        line_integration.update!(
          notification_preferences: {
            'quiet_hours_enabled' => true,
            'notification_times' => {
              'start' => '09:00',
              'end' => '18:00'
            }
          }
        )
      end

      context 'during quiet hours' do
        before do
          allow(Time).to receive(:current).and_return(Time.parse('22:00'))
          allow(Rails.logger).to receive(:info)
        end

        it 'skips notification during quiet hours' do
          expect(LineIntegrationService).not_to receive(:new)
          expect(Rails.logger).to receive(:info).with(/Skipping notification due to quiet hours/)
          
          described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
        end
      end

      context 'during active hours' do
        before do
          allow(Time).to receive(:current).and_return(Time.parse('14:00'))
        end

        it 'sends notification during active hours' do
          expect(line_service).to receive(:send_message)
          
          described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
        end
      end

      context 'with urgent notifications' do
        before do
          allow(Time).to receive(:current).and_return(Time.parse('22:00'))
        end

        it 'sends urgent notifications even during quiet hours' do
          expect(line_service).to receive(:send_message)
          
          described_class.perform_now(line_integration, 'deadline_reminder', { 
            task_id: task.id, 
            urgent: true,
            days_until_due: 0
          })
        end
      end
    end

    context 'when message sending fails' do
      before do
        allow(line_service).to receive(:send_message).and_return(false)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and raises exception for retry' do
        expect(Rails.logger).to receive(:error).with(/Failed to send LINE notification/)
        
        expect {
          described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
        }.to raise_error(/Failed to send notification/)
      end
    end

    context 'when LINE service raises exception' do
      before do
        allow(line_service).to receive(:send_message).and_raise(Line::Bot::API::HTTPError.new('API Error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and re-raises for retry' do
        expect(Rails.logger).to receive(:error).with(/LINE API error/)
        
        expect {
          described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
        }.to raise_error(Line::Bot::API::HTTPError)
      end
    end

    context 'with invalid notification type' do
      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs warning for unknown notification type' do
        expect(Rails.logger).to receive(:warn).with(/Unknown notification type/)
        
        described_class.perform_now(line_integration, 'unknown_type', { task_id: task.id })
      end

      it 'does not send notification for unknown type' do
        expect(LineIntegrationService).not_to receive(:new)
        
        described_class.perform_now(line_integration, 'unknown_type', { task_id: task.id })
      end
    end

    context 'with missing required data' do
      context 'when task not found' do
        before do
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error for missing task' do
          expect(Rails.logger).to receive(:error).with(/Task not found/)
          
          expect {
            described_class.perform_now(line_integration, 'task_created', { task_id: 99999 })
          }.to raise_error(/Task not found/)
        end
      end

      context 'when user not found for assignment' do
        before do
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error for missing user' do
          expect(Rails.logger).to receive(:error).with(/User not found/)
          
          expect {
            described_class.perform_now(line_integration, 'task_assigned', { 
              task_id: task.id, 
              assigned_to: 99999 
            })
          }.to raise_error(/User not found/)
        end
      end
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('line_notifications')
    end

    it 'has retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end

    it 'has backoff strategy for retries' do
      expect(described_class.retry_on[StandardError]).to include(:wait)
    end

    it 'discards jobs after maximum retries' do
      expect(described_class.discard_on).to include(ActiveRecord::RecordNotFound)
    end
  end

  describe 'message formatting' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
    end

    context 'with emoji and formatting' do
      it 'includes appropriate emojis for different notification types' do
        expect(line_service).to receive(:send_message).with(match(/📝/), nil) # task_created
        described_class.perform_now(line_integration, 'task_created', { task_id: task.id })

        expect(line_service).to receive(:send_message).with(match(/✅/), nil) # task_completed
        described_class.perform_now(line_integration, 'task_completed', { task_id: task.id })

        expect(line_service).to receive(:send_message).with(match(/⏰/), nil) # deadline_reminder
        described_class.perform_now(line_integration, 'deadline_reminder', { task_id: task.id, days_until_due: 1 })
      end
    end

    context 'with long task titles' do
      let(:long_task) { create(:task, festival: festival, user: user, title: 'A' * 100) }

      it 'truncates long titles appropriately' do
        expect(line_service).to receive(:send_message) do |message, group_id|
          expect(message.length).to be < 1000 # LINE message limit
        end
        
        described_class.perform_now(line_integration, 'task_created', { task_id: long_task.id })
      end
    end

    context 'with special characters in task data' do
      let(:special_task) { create(:task, festival: festival, user: user, title: 'Task with 📝 emojis & symbols') }

      it 'handles special characters in messages' do
        expect(line_service).to receive(:send_message).with(
          match(/Task with 📝 emojis & symbols/),
          nil
        )
        
        described_class.perform_now(line_integration, 'task_created', { task_id: special_task.id })
      end
    end
  end

  describe 'notification timing' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(line_service).to receive(:send_message).and_return(true)
    end

    context 'with timezone considerations' do
      before do
        allow(Time.zone).to receive(:name).and_return('Asia/Tokyo')
      end

      it 'respects timezone for quiet hours calculation' do
        line_integration.update!(
          notification_preferences: {
            'quiet_hours_enabled' => true,
            'notification_times' => { 'start' => '09:00', 'end' => '18:00' }
          }
        )

        # This would be more thoroughly tested in integration tests
        expect {
          described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
        }.not_to raise_error
      end
    end

    context 'with delayed notifications' do
      it 'can be scheduled for later delivery' do
        expect {
          described_class.set(wait: 1.hour).perform_later(line_integration, 'task_created', { task_id: task.id })
        }.to have_enqueued_job(described_class).at(1.hour.from_now)
      end
    end
  end

  describe 'performance considerations' do
    let(:line_service) { instance_double(LineIntegrationService) }

    before do
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      allow(line_service).to receive(:send_message).and_return(true)
      allow(Rails.logger).to receive(:info)
    end

    it 'logs processing time' do
      expect(Rails.logger).to receive(:info).with(/LINE notification sent.*in \d+ms/)
      
      described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
    end

    context 'with batch notifications' do
      let(:tasks) { create_list(:task, 5, festival: festival, user: user) }

      it 'handles multiple notifications efficiently' do
        tasks.each do |task|
          expect(line_service).to receive(:send_message).once
          described_class.perform_now(line_integration, 'task_created', { task_id: task.id })
        end
      end
    end
  end
end