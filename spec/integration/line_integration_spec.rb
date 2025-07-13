require 'rails_helper'

RSpec.describe 'LINE Integration', type: :feature do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:line_group) { create(:line_group, line_integration: line_integration) }

  before do
    sign_in user
  end

  describe 'Integration Setup Workflow' do
    scenario 'User creates and configures LINE integration' do
      visit new_line_integration_path(festival_id: festival.id)
      
      fill_in 'LINE Channel ID', with: '1234567890'
      fill_in 'LINE Channel Secret', with: 'channel_secret_123'
      fill_in 'LINE Access Token', with: 'access_token_123'
      check 'Active'
      
      click_button 'Create LINE Integration'
      
      expect(page).to have_content('LINE連携が正常に作成されました')
      expect(page).to have_content('1234567890')
      
      # Verify integration was created
      integration = LineIntegration.last
      expect(integration.line_channel_id).to eq('1234567890')
      expect(integration.festival).to eq(festival)
      expect(integration.user).to eq(user)
    end

    scenario 'User views integration dashboard' do
      create(:line_group, line_integration: line_integration, name: 'テストグループ')
      create(:line_message, :processed, line_group: line_group)
      
      visit line_integration_path(line_integration)
      
      expect(page).to have_content(line_integration.line_channel_id)
      expect(page).to have_content('テストグループ')
      expect(page).to have_content('Total Groups: 1')
      expect(page).to have_content('Processed Messages: 1')
    end

    scenario 'User tests LINE connection' do
      allow_any_instance_of(LineIntegrationService).to receive(:test_connection).and_return(true)
      
      visit line_integration_path(line_integration)
      
      click_button 'Test Connection', match: :first
      
      expect(page).to have_content('LINE接続テストが成功しました')
    end

    scenario 'User syncs LINE groups' do
      allow_any_instance_of(LineIntegration).to receive(:sync_groups!).and_return(true)
      
      visit groups_line_integration_path(line_integration)
      
      click_button 'Sync Groups'
      
      expect(page).to have_content('グループ同期が完了しました')
    end
  end

  describe 'Message Processing Workflow' do
    let(:message_event) do
      {
        'type' => 'message',
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
        'timestamp' => (Time.current.to_f * 1000).to_i
      }
    end

    scenario 'Webhook processes task creation message' do
      # Mock LINE integration service
      line_service = instance_double(LineIntegrationService)
      allow(LineIntegrationService).to receive(:new).and_return(line_service)
      allow(line_service).to receive(:process_webhook_event) do |event|
        # Simulate message processing
        LineMessage.create!(
          line_group: line_group,
          line_message_id: event['message']['id'],
          message_text: event['message']['text'],
          message_type: event['message']['type'],
          user: user,
          sender_line_user_id: event['source']['userId'],
          line_timestamp: Time.at(event['timestamp'] / 1000.0),
          is_processed: false
        )
      end
      
      expect {
        LineWebhookProcessorJob.perform_now(message_event)
      }.to change(LineMessage, :count).by(1)
      
      message = LineMessage.last
      expect(message.message_text).to eq('タスク: 会場設営をする')
      expect(message.line_group).to eq(line_group)
    end

    scenario 'Task parsing creates task from LINE message' do
      line_message = create(:line_message, 
        line_group: line_group, 
        user: user, 
        message_text: 'タスク: 会場設営をする',
        is_processed: false
      )
      
      expect {
        LineTaskParsingJob.perform_now(line_message)
      }.to change(Task, :count).by(1)
      
      task = Task.last
      expect(task.title).to include('会場設営')
      expect(task.festival).to eq(festival)
      expect(task.created_via_line).to be true
      
      line_message.reload
      expect(line_message.is_processed).to be true
      expect(line_message.task).to eq(task)
      expect(line_message.intent_type).to eq('task_creation')
    end

    scenario 'Task completion through LINE message' do
      existing_task = create(:task, 
        festival: festival, 
        user: user, 
        title: '音響チェック', 
        status: 'in_progress'
      )
      
      line_message = create(:line_message,
        line_group: line_group,
        user: user,
        message_text: '音響チェック完了',
        is_processed: false
      )
      
      LineTaskParsingJob.perform_now(line_message)
      
      existing_task.reload
      expect(existing_task.status).to eq('completed')
      expect(existing_task.completed_at).to be_present
      
      line_message.reload
      expect(line_message.intent_type).to eq('task_completion')
      expect(line_message.task).to eq(existing_task)
    end
  end

  describe 'Notification System' do
    scenario 'Task creation triggers LINE notification' do
      line_service = instance_double(LineIntegrationService)
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      
      expect(line_service).to receive(:send_message).with(
        match(/📝 新しいタスクが作成されました/),
        nil
      ).and_return(true)
      
      task = create(:task, festival: festival, user: user, title: 'テスト作業')
      
      LineNotificationJob.perform_now(line_integration, 'task_created', {
        task_id: task.id,
        assigned_to: user.id
      })
    end

    scenario 'Quiet hours prevent notifications' do
      line_integration.update!(
        notification_preferences: {
          'quiet_hours_enabled' => true,
          'notification_times' => {
            'start' => '09:00',
            'end' => '18:00'
          }
        }
      )
      
      # Simulate time outside quiet hours
      allow(Time).to receive(:current).and_return(Time.parse('22:00'))
      
      expect(LineIntegrationService).not_to receive(:new)
      
      task = create(:task, festival: festival, user: user)
      LineNotificationJob.perform_now(line_integration, 'task_created', { task_id: task.id })
    end

    scenario 'Urgent notifications bypass quiet hours' do
      line_integration.update!(
        notification_preferences: {
          'quiet_hours_enabled' => true,
          'notification_times' => { 'start' => '09:00', 'end' => '18:00' }
        }
      )
      
      allow(Time).to receive(:current).and_return(Time.parse('22:00'))
      
      line_service = instance_double(LineIntegrationService)
      allow(LineIntegrationService).to receive(:new).with(line_integration).and_return(line_service)
      expect(line_service).to receive(:send_message).and_return(true)
      
      task = create(:task, festival: festival, user: user, due_date: Date.current)
      LineNotificationJob.perform_now(line_integration, 'deadline_reminder', {
        task_id: task.id,
        urgent: true,
        days_until_due: 0
      })
    end
  end

  describe 'Group Management' do
    scenario 'User views LINE groups' do
      active_group = create(:line_group, line_integration: line_integration, name: 'アクティブグループ', is_active: true)
      inactive_group = create(:line_group, line_integration: line_integration, name: '非アクティブグループ', is_active: false)
      
      visit groups_line_integration_path(line_integration)
      
      expect(page).to have_content('アクティブグループ')
      expect(page).to have_content('非アクティブグループ')
      expect(page).to have_selector('.active-group', text: 'アクティブグループ')
    end

    scenario 'Group activity tracking' do
      line_group.update!(last_activity_at: 1.hour.ago, member_count: 5)
      
      visit groups_line_integration_path(line_integration)
      
      expect(page).to have_content('Members: 5')
      expect(page).to have_content('Last Activity')
    end
  end

  describe 'Settings Management' do
    scenario 'User updates integration settings', js: true do
      visit line_integration_path(line_integration)
      
      # Navigate to settings (this would require actual UI implementation)
      within('.settings-panel') do
        uncheck 'Auto Task Creation'
        check 'Debug Mode'
        click_button 'Save Settings'
      end
      
      expect(page).to have_content('設定が更新されました')
      
      line_integration.reload
      expect(line_integration.settings['auto_task_creation']).to be false
      expect(line_integration.settings['debug_mode']).to be true
    end

    scenario 'User configures notification preferences' do
      visit line_integration_path(line_integration)
      
      within('.notification-settings') do
        uncheck 'Task Created Notifications'
        check 'Quiet Hours Enabled'
        fill_in 'Start Time', with: '22:00'
        fill_in 'End Time', with: '08:00'
        click_button 'Update Preferences'
      end
      
      line_integration.reload
      expect(line_integration.notification_preferences['task_created']).to be false
      expect(line_integration.notification_preferences['quiet_hours_enabled']).to be true
    end
  end

  describe 'Error Handling' do
    scenario 'Invalid LINE credentials show error' do
      allow_any_instance_of(LineIntegrationService).to receive(:test_connection).and_return(false)
      
      visit line_integration_path(line_integration)
      click_button 'Test Connection', match: :first
      
      expect(page).to have_content('LINE接続テストに失敗しました')
    end

    scenario 'Webhook setup failure shows error' do
      allow_any_instance_of(LineIntegration).to receive(:sync_groups!).and_return(false)
      
      visit groups_line_integration_path(line_integration)
      click_button 'Sync Groups'
      
      expect(page).to have_content('グループ同期に失敗しました')
    end

    scenario 'Missing LINE integration shows 404' do
      visit line_integration_path(id: 99999)
      
      expect(page).to have_http_status(:not_found)
    end
  end

  describe 'Security and Authorization' do
    let(:other_user) { create(:user) }
    let(:other_festival) { create(:festival, user: other_user) }
    let(:other_integration) { create(:line_integration, festival: other_festival, user: other_user) }

    scenario 'User cannot access other user LINE integration' do
      visit line_integration_path(other_integration)
      
      expect(page).to have_content('権限がありません')
      expect(current_path).to eq(line_integrations_path)
    end

    scenario 'User cannot modify other user LINE integration' do
      patch line_integration_path(other_integration), params: {
        line_integration: { is_active: false }
      }
      
      expect(response).to redirect_to(line_integrations_path)
      follow_redirect!
      expect(response.body).to include('権限がありません')
    end
  end

  describe 'Performance and Scalability' do
    scenario 'Dashboard loads efficiently with many groups and messages' do
      # Create multiple groups and messages
      groups = create_list(:line_group, 10, line_integration: line_integration)
      groups.each do |group|
        create_list(:line_message, 20, line_group: group)
      end
      
      start_time = Time.current
      visit line_integration_path(line_integration)
      load_time = Time.current - start_time
      
      expect(load_time).to be < 2.seconds
      expect(page).to have_content('Total Groups: 10')
    end

    scenario 'Message processing handles high volume' do
      messages = []
      100.times do |i|
        messages << create(:line_message, 
          line_group: line_group, 
          message_text: "タスク: テスト作業#{i}",
          is_processed: false
        )
      end
      
      start_time = Time.current
      messages.each { |msg| LineTaskParsingJob.perform_now(msg) }
      processing_time = Time.current - start_time
      
      expect(processing_time).to be < 30.seconds
      expect(Task.where(created_via_line: true).count).to eq(100)
    end
  end

  describe 'Real-time Features' do
    scenario 'Webhook endpoint handles LINE events', js: true do
      webhook_body = {
        events: [
          {
            type: 'message',
            message: {
              id: 'msg_real_time_test',
              type: 'text',
              text: 'リアルタイムテスト'
            },
            source: {
              groupId: line_group.line_group_id,
              userId: 'U_test_user'
            },
            timestamp: Time.current.to_i * 1000
          }
        ]
      }.to_json
      
      # Mock LINE signature verification
      allow_any_instance_of(LineIntegrationsController).to receive(:verify_webhook_signature).and_return(true)
      
      post '/line_integrations/callback', 
           params: webhook_body,
           headers: { 
             'Content-Type' => 'application/json',
             'X-Line-Signature' => 'valid_signature'
           }
      
      expect(response).to have_http_status(:ok)
      
      # Verify job was queued
      expect(LineWebhookProcessorJob).to have_been_enqueued
    end
  end

  describe 'Data Analytics and Reporting' do
    scenario 'Integration statistics are accurate' do
      # Create test data
      active_groups = create_list(:line_group, 3, line_integration: line_integration, is_active: true)
      inactive_groups = create_list(:line_group, 2, line_integration: line_integration, is_active: false)
      
      active_groups.each do |group|
        create_list(:line_message, 5, :processed, line_group: group)
        create_list(:line_message, 2, line_group: group, is_processed: false)
      end
      
      visit line_integration_path(line_integration)
      
      expect(page).to have_content('Total Groups: 5')
      expect(page).to have_content('Active Groups: 3')
      expect(page).to have_content('Total Messages: 21') # 3 groups * 7 messages each
      expect(page).to have_content('Processed Messages: 15') # 3 groups * 5 processed each
    end

    scenario 'Webhook status dashboard shows comprehensive metrics' do
      create_list(:line_message, 10, :processed, line_group: line_group)
      create_list(:line_message, 3, :processing_failed, line_group: line_group)
      create_list(:line_message, 2, line_group: line_group, created_at: 2.hours.ago)
      
      visit webhook_status_line_integrations_path
      
      expect(page).to have_content('Total Webhooks: 15')
      expect(page).to have_content('Processed Webhooks: 10')
      expect(page).to have_content('Failed Webhooks: 3')
      expect(page).to have_content('Recent Activity')
    end
  end

  describe 'Integration Health Monitoring' do
    scenario 'Integration status reflects health accurately' do
      line_integration.update!(
        status: :active,
        last_webhook_received_at: 5.minutes.ago,
        last_sync_at: 1.hour.ago
      )
      
      visit line_integration_path(line_integration)
      
      expect(page).to have_selector('.status-indicator.active')
      expect(page).to have_content('Last Webhook: 5 minutes ago')
      expect(page).to have_content('Last Sync: 1 hour ago')
    end

    scenario 'Error status shows troubleshooting information' do
      line_integration.update!(
        status: :error,
        last_error_message: 'API connection failed',
        last_error_at: 10.minutes.ago
      )
      
      visit line_integration_path(line_integration)
      
      expect(page).to have_selector('.status-indicator.error')
      expect(page).to have_content('API connection failed')
      expect(page).to have_content('10 minutes ago')
      expect(page).to have_link('Troubleshooting Guide')
    end
  end
end