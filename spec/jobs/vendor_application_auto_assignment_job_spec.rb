require 'rails_helper'

RSpec.describe VendorApplicationAutoAssignmentJob, type: :job do
  let(:festival) { create(:festival) }
  let(:user) { create(:user) }
  let(:vendor_application) { create(:vendor_application, festival: festival, user: user, status: 'submitted') }
  let!(:reviewer_1) { create(:user, :reviewer, specializations: ['food_beverage']) }
  let!(:reviewer_2) { create(:user, :reviewer, specializations: ['retail']) }
  let!(:reviewer_3) { create(:user, :reviewer, specializations: ['food_beverage', 'retail']) }

  describe '#perform' do
    context 'with newly submitted application' do
      it 'assigns reviewers based on specialization' do
        vendor_application.update!(business_category: 'food_beverage')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.primary_reviewer).to be_present
        expect([reviewer_1.id, reviewer_3.id]).to include(vendor_application.primary_reviewer_id)
      end

      it 'assigns secondary reviewer for complex applications' do
        vendor_application.update!(
          business_category: 'food_beverage',
          complexity_score: 85
        )
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.secondary_reviewer).to be_present
        expect(vendor_application.secondary_reviewer_id).not_to eq(vendor_application.primary_reviewer_id)
      end

      it 'balances workload across reviewers' do
        # Create existing assignments for reviewer_1
        create_list(:vendor_application, 5, 
          festival: festival, 
          primary_reviewer: reviewer_1,
          status: 'under_review'
        )
        
        vendor_application.update!(business_category: 'food_beverage')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        # Should prefer reviewer_3 who has less workload
        expect(vendor_application.primary_reviewer_id).to eq(reviewer_3.id)
      end

      it 'considers reviewer availability' do
        reviewer_1.update!(available: false)
        reviewer_3.update!(available: false)
        
        vendor_application.update!(business_category: 'food_beverage')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        # Should fall back to general assignment
        expect(vendor_application.primary_reviewer).to be_present
      end

      it 'updates application status' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.status).to eq('under_review')
      end

      it 'records assignment timestamp' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.assigned_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'with priority applications' do
      before do
        vendor_application.update!(priority: 'high')
      end

      it 'assigns high-priority applications first' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.primary_reviewer).to be_present
        expect(vendor_application.assigned_at).to be_within(1.second).of(Time.current)
      end

      it 'notifies reviewers immediately for urgent applications' do
        vendor_application.update!(priority: 'urgent')
        
        expect {
          described_class.perform_now(vendor_application.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context 'with specialty requirements' do
      before do
        vendor_application.update!(
          business_category: 'food_beverage',
          special_requirements: ['organic_certification', 'vegan_options']
        )
      end

      it 'matches specialized reviewers' do
        reviewer_1.update!(certifications: ['organic_specialist'])
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.primary_reviewer_id).to eq(reviewer_1.id)
      end

      it 'creates detailed assignment notes' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.reviewer_notes).to include('special_requirements')
      end
    end

    context 'with no suitable reviewers' do
      before do
        User.where(role: 'reviewer').update_all(available: false)
      end

      it 'escalates to admin assignment' do
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.assignment_status).to eq('escalated')
        expect(vendor_application.escalation_reason).to include('No available reviewers')
      end

      it 'notifies administrators' do
        expect {
          described_class.perform_now(vendor_application.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context 'with already assigned application' do
      before do
        vendor_application.update!(
          primary_reviewer: reviewer_1,
          status: 'under_review'
        )
      end

      it 'skips already assigned applications' do
        original_reviewer = vendor_application.primary_reviewer
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.primary_reviewer).to eq(original_reviewer)
      end

      it 'allows reassignment if forced' do
        described_class.perform_now(vendor_application.id, force_reassign: true)
        
        vendor_application.reload
        expect(vendor_application.reassignment_count).to eq(1)
      end
    end

    context 'with batch assignment' do
      let!(:applications) { create_list(:vendor_application, 5, festival: festival, status: 'submitted') }

      it 'processes multiple applications efficiently' do
        applications.each do |app|
          described_class.perform_later(app.id)
        end
        
        expect(described_class).to have_been_enqueued.exactly(5).times
      end

      it 'maintains assignment balance across batch' do
        applications.each { |app| described_class.perform_now(app.id) }
        
        # Check that assignments are distributed
        reviewer_counts = applications.map(&:reload).group_by(&:primary_reviewer_id).transform_values(&:count)
        expect(reviewer_counts.values.max - reviewer_counts.values.min).to be <= 2
      end
    end
  end

  describe 'assignment algorithms' do
    describe 'workload balancing' do
      it 'calculates current workload correctly' do
        create_list(:vendor_application, 3, primary_reviewer: reviewer_1, status: 'under_review')
        create_list(:vendor_application, 1, primary_reviewer: reviewer_2, status: 'under_review')
        
        vendor_application.update!(business_category: 'food_beverage')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        # Should assign to reviewer_3 (0 workload) rather than reviewer_1 (3 workload)
        expect(vendor_application.primary_reviewer_id).to eq(reviewer_3.id)
      end

      it 'considers application complexity in workload calculation' do
        # Create high-complexity application for reviewer_1
        create(:vendor_application, 
          primary_reviewer: reviewer_1, 
          status: 'under_review',
          complexity_score: 90
        )
        
        vendor_application.update!(
          business_category: 'food_beverage',
          complexity_score: 30
        )
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.primary_reviewer_id).to eq(reviewer_3.id)
      end
    end

    describe 'specialization matching' do
      it 'prioritizes exact specialization matches' do
        vendor_application.update!(business_category: 'food_beverage')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        assigned_reviewer = User.find(vendor_application.primary_reviewer_id)
        expect(assigned_reviewer.specializations).to include('food_beverage')
      end

      it 'falls back to partial matches' do
        vendor_application.update!(business_category: 'entertainment')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        expect(vendor_application.primary_reviewer).to be_present
      end
    end

    describe 'performance scoring' do
      before do
        reviewer_1.update!(performance_score: 95.0)
        reviewer_2.update!(performance_score: 78.5)
        reviewer_3.update!(performance_score: 88.2)
      end

      it 'considers reviewer performance in assignment' do
        vendor_application.update!(business_category: 'food_beverage')
        
        described_class.perform_now(vendor_application.id)
        
        vendor_application.reload
        # Should prefer higher-performing reviewer_1 over reviewer_3
        expect(vendor_application.primary_reviewer_id).to eq(reviewer_1.id)
      end
    end
  end

  describe 'notification handling' do
    it 'sends assignment notification to reviewer' do
      expect {
        described_class.perform_now(vendor_application.id)
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it 'sends confirmation to applicant' do
      described_class.perform_now(vendor_application.id)
      
      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued.at_least(:once)
    end

    it 'handles notification delivery failures gracefully' do
      allow(VendorApplicationMailer).to receive(:reviewer_assignment).and_raise(Net::SMTPError)
      
      expect {
        described_class.perform_now(vendor_application.id)
      }.not_to raise_error
      
      vendor_application.reload
      expect(vendor_application.primary_reviewer).to be_present
    end
  end

  describe 'error handling' do
    it 'handles missing application records' do
      expect {
        described_class.perform_now(999999)
      }.not_to raise_error
    end

    it 'handles database connection issues' do
      allow(VendorApplication).to receive(:find).and_raise(ActiveRecord::ConnectionTimeoutError)
      
      expect {
        described_class.perform_now(vendor_application.id)
      }.to raise_error(ActiveRecord::ConnectionTimeoutError)
    end

    it 'retries on temporary failures' do
      call_count = 0
      allow(VendorApplicationWorkflowService).to receive(:auto_assign_reviewers) do
        call_count += 1
        if call_count < 3
          raise StandardError, 'Temporary failure'
        else
          { success: true, assigned_reviewers: [{ reviewer_id: reviewer_1.id }] }
        end
      end
      
      described_class.perform_now(vendor_application.id)
      
      vendor_application.reload
      expect(vendor_application.primary_reviewer).to be_present
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('application_processing')
    end

    it 'has appropriate priority' do
      expect(described_class.priority).to be >= 0
    end

    it 'retries failed assignments' do
      expect(described_class.retry_limit).to be > 0
    end
  end

  describe 'analytics and monitoring' do
    it 'tracks assignment metrics' do
      expect {
        described_class.perform_now(vendor_application.id)
      }.to change(ApplicationAnalytic, :count).by_at_least(1)
    end

    it 'measures assignment performance' do
      start_time = Time.current
      
      described_class.perform_now(vendor_application.id)
      
      elapsed_time = Time.current - start_time
      expect(elapsed_time).to be < 5.seconds
    end

    it 'logs assignment decisions' do
      expect(Rails.logger).to receive(:info).with(/Application assigned/)
      
      described_class.perform_now(vendor_application.id)
    end
  end
end