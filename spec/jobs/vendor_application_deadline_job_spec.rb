require 'rails_helper'

RSpec.describe VendorApplicationDeadlineJob, type: :job do
  let(:festival) { create(:festival, application_deadline: 1.week.from_now) }
  let(:user) { create(:user) }
  let(:vendor_application) { create(:vendor_application, festival: festival, user: user) }

  describe '#perform' do
    context 'with approaching deadline' do
      before do
        festival.update!(application_deadline: 3.days.from_now)
      end

      it 'sends deadline reminder notifications' do
        expect {
          described_class.perform_now(vendor_application.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it 'updates application with reminder status' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.deadline_reminders_sent).to be > 0
        expect(vendor_application.last_reminder_sent_at).to be_within(1.second).of(Time.current)
      end

      it 'calculates days remaining correctly' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        reminder_data = vendor_application.reminder_metadata || {}
        expect(reminder_data['days_remaining']).to be_between(2, 4)
      end
    end

    context 'with urgent deadline (24 hours)' do
      before do
        festival.update!(application_deadline: 18.hours.from_now)
      end

      it 'sends urgent notification' do
        expect {
          described_class.perform_now(vendor_application.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob).with(
          'VendorApplicationMailer',
          'urgent_deadline_reminder',
          'deliver_now',
          { args: [vendor_application] }
        )
      end

      it 'marks application as urgent' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.priority).to eq('urgent')
      end

      it 'escalates to admin if incomplete' do
        vendor_application.update!(status: 'draft', completion_percentage: 30)
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.escalated_to_admin).to be true
      end
    end

    context 'with overdue application' do
      before do
        festival.update!(application_deadline: 1.day.ago)
      end

      it 'marks application as overdue' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.status).to eq('overdue')
        expect(vendor_application.overdue_at).to be_within(1.second).of(Time.current)
      end

      it 'sends overdue notification' do
        expect {
          described_class.perform_now(vendor_application.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it 'archives incomplete applications after grace period' do
        vendor_application.update!(
          status: 'draft',
          created_at: 10.days.ago
        )
        festival.update!(application_deadline: 5.days.ago)
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.status).to eq('expired')
        expect(vendor_application.archived_at).to be_present
      end
    end

    context 'with completed application' do
      before do
        vendor_application.update!(
          status: 'submitted',
          completion_percentage: 100,
          submitted_at: 1.day.ago
        )
        festival.update!(application_deadline: 1.day.from_now)
      end

      it 'skips deadline reminders for completed applications' do
        expect {
          described_class.perform_now(vendor_application.id)
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it 'does not update reminder counts' do
        original_count = vendor_application.deadline_reminders_sent
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.deadline_reminders_sent).to eq(original_count)
      end
    end

    context 'with extension granted' do
      before do
        vendor_application.update!(
          deadline_extension: 1.week.from_now,
          extension_reason: 'Medical emergency'
        )
        festival.update!(application_deadline: 1.day.ago)
      end

      it 'uses extended deadline for calculations' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.status).not_to eq('overdue')
      end

      it 'sends extension-specific reminders' do
        described_class.perform_now(vendor_application.id)
        
        expect(ActionMailer::MailDeliveryJob).to have_been_enqueued
      end
    end

    context 'with festival postponement' do
      before do
        festival.update!(
          application_deadline: 2.weeks.from_now,
          postponement_reason: 'Venue unavailable'
        )
      end

      it 'sends postponement notification' do
        described_class.perform_now(vendor_application.id)
        
        expect(ActionMailer::MailDeliveryJob).to have_been_enqueued
      end

      it 'updates application with new timeline' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        timeline = vendor_application.reminder_metadata || {}
        expect(timeline['postponement_notified']).to be true
      end
    end
  end

  describe 'reminder scheduling' do
    it 'schedules reminders based on deadline proximity' do
      festival.update!(application_deadline: 7.days.from_now)
      
      described_class.perform_now(vendor_application.id)
      
      vendor_application.reload
      expect(vendor_application.next_reminder_at).to be_present
    end

    it 'increases reminder frequency as deadline approaches' do
      # First reminder at 7 days
      festival.update!(application_deadline: 7.days.from_now)
      described_class.perform_now(vendor_application.id)
      vendor_application.reload
      next_reminder_1 = vendor_application.next_reminder_at
      
      # Second reminder at 3 days
      festival.update!(application_deadline: 3.days.from_now)
      described_class.perform_now(vendor_application.id)
      vendor_application.reload
      next_reminder_2 = vendor_application.next_reminder_at
      
      # Frequency should increase (shorter intervals)
      expect(next_reminder_2 - Time.current).to be < (next_reminder_1 - Time.current)
    end

    it 'respects user notification preferences' do
      user.update!(notification_preferences: { deadline_reminders: false })
      
      expect {
        described_class.perform_now(vendor_application.id)
      }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe 'batch processing' do
    let!(:applications) { create_list(:vendor_application, 10, festival: festival, user: user) }

    before do
      festival.update!(application_deadline: 2.days.from_now)
    end

    it 'processes multiple applications efficiently' do
      start_time = Time.current
      
      applications.each do |app|
        described_class.perform_now(app.id)
      end
      
      elapsed_time = Time.current - start_time
      expect(elapsed_time).to be < 30.seconds
    end

    it 'handles errors in individual applications gracefully' do
      # Corrupt one application
      applications.first.update!(festival_id: nil)
      
      expect {
        applications.each { |app| described_class.perform_now(app.id) }
      }.not_to raise_error
      
      # Other applications should still be processed
      applications[1].reload
      expect(applications[1].deadline_reminders_sent).to be > 0
    end
  end

  describe 'notification content customization' do
    it 'personalizes reminder messages' do
      described_class.perform_now(vendor_application.id)
      
      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued.with(
        'VendorApplicationMailer',
        anything,
        'deliver_now',
        { args: [vendor_application] }
      )
    end

    it 'includes relevant deadline information' do
      festival.update!(application_deadline: 5.days.from_now)
      
      described_class.perform_now(vendor_application.id)
      
      vendor_application.reload
      metadata = vendor_application.reminder_metadata || {}
      expect(metadata).to include('days_remaining', 'deadline_formatted')
    end

    it 'adapts content based on application status' do
      vendor_application.update!(completion_percentage: 45)
      
      described_class.perform_now(vendor_application.id)
      
      vendor_application.reload
      metadata = vendor_application.reminder_metadata || {}
      expect(metadata['completion_status']).to include('45%')
    end
  end

  describe 'analytics and reporting' do
    it 'tracks reminder effectiveness' do
      described_class.perform_now(vendor_application.id)
      
      expect {
        vendor_application.update!(completion_percentage: vendor_application.completion_percentage + 10)
      }.to change { vendor_application.reminder_metadata&.dig('completion_improvement') }
    end

    it 'measures deadline pressure impact' do
      festival.update!(application_deadline: 1.day.from_now)
      
      described_class.perform_now(vendor_application.id)
      
      vendor_application.reload
      expect(vendor_application.reminder_metadata).to include('deadline_pressure')
    end

    it 'records festival-level deadline statistics' do
      expect {
        described_class.perform_now(vendor_application.id)
      }.to change(ApplicationAnalytic, :count).by_at_least(1)
    end
  end

  describe 'error handling and resilience' do
    it 'handles missing festival gracefully' do
      vendor_application.update!(festival_id: nil)
      
      expect {
        described_class.perform_now(vendor_application.id)
      }.not_to raise_error
    end

    it 'handles email delivery failures' do
      allow(VendorApplicationMailer).to receive(:deadline_reminder).and_raise(Net::SMTPError)
      
      expect {
        described_class.perform_now(vendor_application.id)
      }.not_to raise_error
      
      vendor_application.reload
      expect(vendor_application.reminder_metadata).to include('delivery_failed')
    end

    it 'retries on temporary failures' do
      call_count = 0
      allow(VendorApplication).to receive(:find) do |id|
        call_count += 1
        if call_count < 3
          raise ActiveRecord::ConnectionTimeoutError
        else
          vendor_application
        end
      end
      
      expect {
        described_class.perform_now(vendor_application.id)
      }.to raise_error(ActiveRecord::ConnectionTimeoutError)
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('deadline_management')
    end

    it 'has appropriate retry settings' do
      expect(described_class.retry_limit).to be >= 3
    end

    it 'handles job scheduling correctly' do
      expect {
        described_class.perform_later(vendor_application.id)
      }.to have_enqueued_job(described_class).with(vendor_application.id)
    end
  end
end