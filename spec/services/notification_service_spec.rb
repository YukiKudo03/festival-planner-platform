require 'rails_helper'

RSpec.describe NotificationService, type: :service do
  let(:user) { create(:user, :committee_member) }
  let(:sender) { create(:user, :admin) }
  let(:festival) { create(:festival, user: user) }
  let(:task) { create(:task, festival: festival, user: user) }

  describe '.create_notification' do
    let(:params) do
      {
        recipient: user,
        sender: sender,
        notifiable: task,
        notification_type: 'task_assigned',
        title: 'Test Notification',
        message: 'Test message'
      }
    end

    it 'creates a notification' do
      expect {
        NotificationService.create_notification(params)
      }.to change(Notification, :count).by(1)
    end

    it 'returns the created notification' do
      notification = NotificationService.create_notification(params)
      expect(notification).to be_a(Notification)
      expect(notification.title).to eq('Test Notification')
    end

    context 'when user has email notifications enabled and immediate frequency' do
      before do
        create(:notification_setting, 
               user: user, 
               notification_type: 'task_assigned',
               email_enabled: true,
               frequency: 'immediate')
      end

      it 'enqueues email delivery' do
        expect {
          NotificationService.create_notification(params)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context 'when user has web notifications enabled and immediate frequency' do
      before do
        create(:notification_setting,
               user: user,
               notification_type: 'task_assigned', 
               web_enabled: true,
               frequency: 'immediate')
      end

      it 'broadcasts notification via ActionCable' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "notifications_#{user.id}",
          hash_including(
            title: 'Test Notification',
            message: 'Test message',
            notification_type: 'task_assigned'
          )
        )
        
        NotificationService.create_notification(params)
      end
    end
  end

  describe '.send_task_deadline_reminder' do
    let(:other_user) { create(:user, :volunteer) }
    let!(:other_task) { create(:task, festival: festival, user: other_user) }

    it 'sends notifications to other festival task users' do
      expect {
        NotificationService.send_task_deadline_reminder(task)
      }.to change(Notification, :count).by(1)
    end

    it 'does not send notification to the task owner' do
      NotificationService.send_task_deadline_reminder(task)
      
      notifications = Notification.where(recipient: user)
      expect(notifications).to be_empty
    end

    it 'creates notification with correct type and message' do
      NotificationService.send_task_deadline_reminder(task)
      
      notification = Notification.last
      expect(notification.notification_type).to eq('task_deadline_reminder')
      expect(notification.title).to eq('タスクの期限が近づいています')
      expect(notification.message).to include(task.title)
    end
  end

  describe '.send_task_overdue_notification' do
    it 'creates overdue notification for task user' do
      expect {
        NotificationService.send_task_overdue_notification(task)
      }.to change(Notification, :count).by(1)
    end

    it 'sends notification to task owner' do
      NotificationService.send_task_overdue_notification(task)
      
      notification = Notification.last
      expect(notification.recipient).to eq(user)
      expect(notification.notification_type).to eq('task_overdue')
    end
  end

  describe '.send_task_assigned_notification' do
    it 'creates task assigned notification' do
      expect {
        NotificationService.send_task_assigned_notification(task, sender)
      }.to change(Notification, :count).by(1)
    end

    it 'includes sender information' do
      NotificationService.send_task_assigned_notification(task, sender)
      
      notification = Notification.last
      expect(notification.sender).to eq(sender)
      expect(notification.notification_type).to eq('task_assigned')
    end
  end

  describe '.send_task_status_changed_notification' do
    let(:other_user) { create(:user, :volunteer) }
    let!(:other_task) { create(:task, festival: festival, user: other_user) }

    it 'sends notifications to festival participants except task owner' do
      expect {
        NotificationService.send_task_status_changed_notification(task, 'pending')
      }.to change(Notification, :count).by(1)
    end

    it 'includes status change information' do
      NotificationService.send_task_status_changed_notification(task, 'pending')
      
      notification = Notification.last
      expect(notification.message).to include('pending')
      expect(notification.message).to include(task.status)
    end
  end

  describe '.send_vendor_application_submitted_notification' do
    let(:vendor_application) { create(:vendor_application, festival: festival) }
    let(:festival_manager) { create(:user, :admin) }

    before do
      festival.update(user: festival_manager)
    end

    it 'sends notification to festival managers' do
      expect {
        NotificationService.send_vendor_application_submitted_notification(vendor_application)
      }.to change(Notification, :count).by(1)
    end

    it 'notifies the correct festival manager' do
      NotificationService.send_vendor_application_submitted_notification(vendor_application)
      
      notification = Notification.last
      expect(notification.recipient).to eq(festival_manager)
      expect(notification.notification_type).to eq('vendor_application_submitted')
    end
  end

  describe '.send_vendor_application_status_notification' do
    let(:vendor_application) { create(:vendor_application, festival: festival) }

    context 'when application is approved' do
      it 'sends approval notification' do
        expect {
          NotificationService.send_vendor_application_status_notification(vendor_application, 'approved')
        }.to change(Notification, :count).by(1)
      end

      it 'creates correct notification type' do
        NotificationService.send_vendor_application_status_notification(vendor_application, 'approved')
        
        notification = Notification.last
        expect(notification.notification_type).to eq('vendor_application_approved')
        expect(notification.title).to eq('出店申請が承認されました')
      end
    end

    context 'when application is rejected' do
      it 'sends rejection notification' do
        NotificationService.send_vendor_application_status_notification(vendor_application, 'rejected')
        
        notification = Notification.last
        expect(notification.notification_type).to eq('vendor_application_rejected')
        expect(notification.title).to eq('出店申請が却下されました')
      end
    end
  end

  describe '.send_festival_created_notification' do
    it 'sends notifications to residents and volunteers' do
      create(:user, :resident)
      create(:user, :volunteer)
      create(:user, :admin) # Should not receive notification
      
      expect {
        NotificationService.send_festival_created_notification(festival)
      }.to change(Notification, :count).by(2)
    end

    it 'creates correct notification content' do
      resident = create(:user, :resident)
      
      NotificationService.send_festival_created_notification(festival)
      
      notification = Notification.where(recipient: resident).first
      expect(notification.notification_type).to eq('festival_created')
      expect(notification.message).to include(festival.name)
    end
  end
end