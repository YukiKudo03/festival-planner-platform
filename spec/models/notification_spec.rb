require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:notification_type) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:recipient) }
    it { should validate_inclusion_of(:notification_type).in_array(Notification::NOTIFICATION_TYPES) }
  end

  describe 'associations' do
    it { should belong_to(:recipient).class_name('User') }
    it { should belong_to(:sender).class_name('User').optional }
    it { should belong_to(:notifiable) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:unread_notification) { create(:notification, recipient: user, read_at: nil) }
    let!(:read_notification) { create(:notification, recipient: user, read_at: 1.hour.ago) }

    describe '.unread' do
      it 'returns unread notifications' do
        expect(Notification.unread).to include(unread_notification)
        expect(Notification.unread).not_to include(read_notification)
      end
    end

    describe '.read' do
      it 'returns read notifications' do
        expect(Notification.read).to include(read_notification)
        expect(Notification.read).not_to include(unread_notification)
      end
    end

    describe '.recent' do
      it 'orders notifications by created_at desc' do
        # Clear any existing notifications to avoid interference
        Notification.delete_all
        
        # Disable model callbacks to avoid interference
        allow_any_instance_of(Task).to receive(:send_task_assigned_notification)
        allow_any_instance_of(Task).to receive(:send_status_change_notification)
        
        older_notification = travel_to(2.hours.ago) { create(:notification, recipient: user) }
        newer_notification = travel_to(1.hour.ago) { create(:notification, recipient: user) }
        
        notifications = Notification.recent
        expect(notifications.first).to eq(newer_notification)
        expect(notifications.last).to eq(older_notification)
      end
    end

    describe '.by_type' do
      it 'filters by notification type' do
        task_notification = create(:notification, notification_type: 'task_assigned')
        vendor_notification = create(:notification, notification_type: 'vendor_application_submitted')
        
        expect(Notification.by_type('task_assigned')).to include(task_notification)
        expect(Notification.by_type('task_assigned')).not_to include(vendor_notification)
      end
    end

    describe '.for_user' do
      it 'filters by recipient user' do
        other_user = create(:user)
        user_notification = create(:notification, recipient: user)
        other_notification = create(:notification, recipient: other_user)
        
        expect(Notification.for_user(user)).to include(user_notification)
        expect(Notification.for_user(user)).not_to include(other_notification)
      end
    end
  end

  describe 'instance methods' do
    let(:notification) { create(:notification) }

    describe '#read?' do
      it 'returns true when read_at is present' do
        notification.update(read_at: 1.hour.ago)
        expect(notification.read?).to be true
      end

      it 'returns false when read_at is nil' do
        notification.update(read_at: nil)
        expect(notification.read?).to be false
      end
    end

    describe '#unread?' do
      it 'returns false when read_at is present' do
        notification.update(read_at: 1.hour.ago)
        expect(notification.unread?).to be false
      end

      it 'returns true when read_at is nil' do
        notification.update(read_at: nil)
        expect(notification.unread?).to be true
      end
    end

    describe '#mark_as_read!' do
      it 'sets read_at to current time when unread' do
        notification.update(read_at: nil)
        
        travel_to Time.current do
          notification.mark_as_read!
          expect(notification.read_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'does not change read_at when already read' do
        original_time = 1.hour.ago
        notification.update(read_at: original_time)
        
        notification.mark_as_read!
        expect(notification.read_at).to be_within(1.second).of(original_time)
      end
    end

    describe '#mark_as_unread!' do
      it 'sets read_at to nil when read' do
        notification.update(read_at: 1.hour.ago)
        
        notification.mark_as_unread!
        expect(notification.read_at).to be_nil
      end

      it 'does not change read_at when already unread' do
        notification.update(read_at: nil)
        
        notification.mark_as_unread!
        expect(notification.read_at).to be_nil
      end
    end
  end

  describe 'class methods' do
    let(:user) { create(:user) }

    describe '.mark_all_as_read_for_user' do
      it 'marks all unread notifications as read for user' do
        unread1 = create(:notification, recipient: user, read_at: nil)
        unread2 = create(:notification, recipient: user, read_at: nil)
        already_read = create(:notification, recipient: user, read_at: 1.hour.ago)
        other_user_notification = create(:notification, read_at: nil)
        
        travel_to Time.current do
          Notification.mark_all_as_read_for_user(user)
          
          expect(unread1.reload.read_at).to be_within(1.second).of(Time.current)
          expect(unread2.reload.read_at).to be_within(1.second).of(Time.current)
          expect(already_read.reload.read_at).to be_within(1.second).of(1.hour.ago)
          expect(other_user_notification.reload.read_at).to be_nil
        end
      end
    end

    describe '.cleanup_old_notifications' do
      it 'deletes notifications older than specified days' do
        old_notification = create(:notification, created_at: 91.days.ago)
        recent_notification = create(:notification, created_at: 89.days.ago)
        
        expect {
          Notification.cleanup_old_notifications(90)
        }.to change(Notification, :count).by(-1)
        
        expect(Notification.exists?(old_notification.id)).to be false
        expect(Notification.exists?(recent_notification.id)).to be true
      end
    end
  end

  describe 'constants' do
    it 'defines NOTIFICATION_TYPES' do
      expected_types = %w[
        task_deadline_reminder
        task_overdue
        task_assigned
        task_status_changed
        festival_created
        festival_updated
        vendor_application_submitted
        vendor_application_approved
        vendor_application_rejected
        system_announcement
        forum_reply
        forum_mention
        forum_thread_created
        chat_message
        chat_mention
        expense_approved
        expense_rejected
        revenue_confirmed
        revenue_received
        revenue_status_changed
        budget_exceeded
        budget_warning
        budget_approval_requested
        budget_approval_approved
        budget_approval_rejected
        booth_assigned
        booth_unassigned
        venue_layout_updated
      ]
      
      expect(Notification::NOTIFICATION_TYPES).to eq(expected_types)
    end
  end
end