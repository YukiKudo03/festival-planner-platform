require 'rails_helper'

RSpec.describe VendorApplicationWorkflowService, type: :service do
  let(:festival) { create(:festival) }
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:vendor_application) { create(:vendor_application, festival: festival, user: user) }

  describe '.auto_assign_reviewers' do
    let!(:reviewer_1) { create(:user, :reviewer) }
    let!(:reviewer_2) { create(:user, :reviewer) }
    let!(:reviewer_3) { create(:user, :reviewer) }

    before do
      # Set up reviewer specializations
      reviewer_1.update!(specializations: ['food_beverage'])
      reviewer_2.update!(specializations: ['retail'])
      reviewer_3.update!(specializations: ['food_beverage', 'retail'])
    end

    context 'with available reviewers' do
      it 'assigns reviewers based on workload balancing' do
        vendor_application.update!(business_category: 'food_beverage')
        
        result = described_class.auto_assign_reviewers(vendor_application)
        
        expect(result[:success]).to be true
        expect(result[:assigned_reviewers]).to be_present
        expect(result[:assigned_reviewers].length).to be >= 1
      end

      it 'considers reviewer specializations' do
        vendor_application.update!(business_category: 'food_beverage')
        
        result = described_class.auto_assign_reviewers(vendor_application)
        
        assigned_reviewer_ids = result[:assigned_reviewers].map { |r| r[:reviewer_id] }
        expect(assigned_reviewer_ids).to include(reviewer_1.id).or include(reviewer_3.id)
      end

      it 'balances workload across reviewers' do
        # Create existing assignments for reviewer_1
        create_list(:vendor_application, 5, primary_reviewer: reviewer_1)
        
        vendor_application.update!(business_category: 'food_beverage')
        
        result = described_class.auto_assign_reviewers(vendor_application)
        
        # Should prefer reviewer_3 who has same specialization but less workload
        assigned_reviewer_ids = result[:assigned_reviewers].map { |r| r[:reviewer_id] }
        expect(assigned_reviewer_ids).to include(reviewer_3.id)
      end
    end

    context 'without suitable reviewers' do
      before do
        reviewer_1.update!(specializations: ['technology'])
        reviewer_2.update!(specializations: ['technology'])
        reviewer_3.update!(specializations: ['technology'])
      end

      it 'falls back to general assignment' do
        vendor_application.update!(business_category: 'food_beverage')
        
        result = described_class.auto_assign_reviewers(vendor_application)
        
        expect(result[:success]).to be true
        expect(result[:fallback_assignment]).to be true
      end
    end
  end

  describe '.calculate_application_score' do
    let(:application_data) do
      {
        'business_experience' => '5',
        'previous_events' => '3',
        'business_plan_quality' => 'excellent',
        'financial_stability' => 'good',
        'required_documents' => ['business_license', 'insurance_certificate']
      }
    end

    it 'calculates comprehensive application score' do
      result = described_class.calculate_application_score(vendor_application, application_data)
      
      expect(result[:total_score]).to be_between(0, 100)
      expect(result[:scores]).to have_key(:experience_score)
      expect(result[:scores]).to have_key(:documentation_score)
      expect(result[:scores]).to have_key(:business_plan_score)
      expect(result[:scores]).to have_key(:financial_score)
    end

    it 'provides score breakdown' do
      result = described_class.calculate_application_score(vendor_application, application_data)
      
      expect(result[:breakdown]).to be_an(Array)
      expect(result[:breakdown].first).to have_key(:category)
      expect(result[:breakdown].first).to have_key(:score)
      expect(result[:breakdown].first).to have_key(:max_score)
    end

    it 'handles missing data gracefully' do
      incomplete_data = { 'business_experience' => '2' }
      
      result = described_class.calculate_application_score(vendor_application, incomplete_data)
      
      expect(result[:total_score]).to be >= 0
      expect(result[:warnings]).to be_present
    end
  end

  describe '.send_status_notification' do
    it 'sends notification for status changes' do
      expect {
        described_class.send_status_notification(vendor_application, 'submitted', 'under_review')
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it 'logs notification delivery' do
      expect {
        described_class.send_status_notification(vendor_application, 'submitted', 'under_review')
      }.to change { vendor_application.status_history.count }.by(1)
    end

    it 'handles notification failures gracefully' do
      allow(VendorApplicationMailer).to receive(:status_change_notification).and_raise(StandardError)
      
      expect {
        described_class.send_status_notification(vendor_application, 'submitted', 'under_review')
      }.not_to raise_error
    end
  end

  describe '.process_application_submission' do
    let(:application_data) do
      {
        'business_name' => 'Test Business',
        'contact_email' => 'test@example.com',
        'business_category' => 'food_beverage',
        'documents' => ['business_license.pdf']
      }
    end

    it 'processes complete application submission' do
      result = described_class.process_application_submission(vendor_application, application_data)
      
      expect(result[:success]).to be true
      expect(result[:application_score]).to be_present
      expect(result[:assigned_reviewers]).to be_present
    end

    it 'validates required documents' do
      incomplete_data = application_data.except('documents')
      
      result = described_class.process_application_submission(vendor_application, incomplete_data)
      
      expect(result[:success]).to be false
      expect(result[:errors]).to include(/documents/i)
    end

    it 'triggers workflow automation' do
      expect(VendorApplicationDeadlineJob).to receive(:perform_later).with(vendor_application)
      
      described_class.process_application_submission(vendor_application, application_data)
    end
  end

  describe '.generate_review_assignments' do
    let!(:applications) { create_list(:vendor_application, 10, festival: festival) }
    let!(:reviewers) { create_list(:user, 3, :reviewer) }

    it 'distributes applications evenly among reviewers' do
      assignments = described_class.generate_review_assignments(festival)
      
      expect(assignments).to be_an(Array)
      expect(assignments.length).to eq(applications.length)
      
      # Check distribution balance
      reviewer_counts = assignments.group_by { |a| a[:primary_reviewer_id] }.transform_values(&:count)
      expect(reviewer_counts.values.max - reviewer_counts.values.min).to be <= 1
    end

    it 'considers reviewer specializations and availability' do
      reviewers.first.update!(specializations: ['food_beverage'], available: false)
      applications.first.update!(business_category: 'food_beverage')
      
      assignments = described_class.generate_review_assignments(festival)
      
      assignment = assignments.find { |a| a[:application_id] == applications.first.id }
      expect(assignment[:primary_reviewer_id]).not_to eq(reviewers.first.id)
    end
  end

  describe '.track_application_analytics' do
    it 'records application metrics' do
      expect {
        described_class.track_application_analytics(vendor_application, {
          stage: 'submission',
          duration: 300,
          completion_rate: 85.5
        })
      }.to change(ApplicationAnalytic, :count).by(1)
    end

    it 'aggregates festival-level statistics' do
      described_class.track_application_analytics(vendor_application, {
        stage: 'submission',
        duration: 300
      })
      
      analytics = ApplicationAnalytic.last
      expect(analytics.festival_id).to eq(festival.id)
      expect(analytics.metric_data).to include('duration')
    end
  end

  describe '.escalate_overdue_applications' do
    let!(:overdue_application) do
      create(:vendor_application, 
        festival: festival, 
        status: 'under_review',
        created_at: 15.days.ago
      )
    end
    
    let!(:recent_application) do
      create(:vendor_application, 
        festival: festival, 
        status: 'under_review',
        created_at: 2.days.ago
      )
    end

    it 'identifies overdue applications' do
      result = described_class.escalate_overdue_applications(festival, days_threshold: 10)
      
      expect(result[:escalated_count]).to eq(1)
      expect(result[:escalated_applications]).to include(overdue_application.id)
    end

    it 'sends escalation notifications' do
      expect {
        described_class.escalate_overdue_applications(festival, days_threshold: 10)
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it 'updates application priority' do
      described_class.escalate_overdue_applications(festival, days_threshold: 10)
      
      overdue_application.reload
      expect(overdue_application.priority).to eq('high')
    end
  end

  describe '.generate_workflow_report' do
    let!(:applications) { create_list(:vendor_application, 5, festival: festival) }

    before do
      applications[0].update!(status: 'approved')
      applications[1].update!(status: 'approved')
      applications[2].update!(status: 'rejected')
      applications[3].update!(status: 'under_review')
      applications[4].update!(status: 'submitted')
    end

    it 'generates comprehensive workflow statistics' do
      report = described_class.generate_workflow_report(festival)
      
      expect(report).to have_key(:total_applications)
      expect(report).to have_key(:status_breakdown)
      expect(report).to have_key(:approval_rate)
      expect(report).to have_key(:average_processing_time)
      
      expect(report[:total_applications]).to eq(5)
      expect(report[:status_breakdown]['approved']).to eq(2)
      expect(report[:approval_rate]).to eq(40.0)
    end

    it 'includes reviewer performance metrics' do
      applications.each { |app| app.update!(primary_reviewer: admin_user) }
      
      report = described_class.generate_workflow_report(festival)
      
      expect(report).to have_key(:reviewer_performance)
      expect(report[:reviewer_performance]).to be_an(Array)
    end

    it 'provides trend analysis' do
      # Create applications from different time periods
      create(:vendor_application, festival: festival, created_at: 1.month.ago)
      create(:vendor_application, festival: festival, created_at: 2.weeks.ago)
      
      report = described_class.generate_workflow_report(festival, include_trends: true)
      
      expect(report).to have_key(:weekly_trends)
      expect(report).to have_key(:monthly_trends)
    end
  end

  describe '.optimize_reviewer_assignments' do
    let!(:applications) { create_list(:vendor_application, 8, festival: festival) }
    let!(:reviewers) { create_list(:user, 3, :reviewer) }

    it 'optimizes assignments based on workload and expertise' do
      # Set up different specializations
      reviewers[0].update!(specializations: ['food_beverage'])
      reviewers[1].update!(specializations: ['retail'])
      reviewers[2].update!(specializations: ['food_beverage', 'retail'])
      
      # Set application categories
      applications[0..3].each { |app| app.update!(business_category: 'food_beverage') }
      applications[4..7].each { |app| app.update!(business_category: 'retail') }
      
      result = described_class.optimize_reviewer_assignments(festival)
      
      expect(result[:optimized_assignments]).to be_present
      expect(result[:efficiency_score]).to be > 0
    end

    it 'considers reviewer availability and capacity' do
      reviewers.first.update!(available: false)
      
      result = described_class.optimize_reviewer_assignments(festival)
      
      assignments = result[:optimized_assignments]
      assigned_reviewers = assignments.map { |a| a[:reviewer_id] }.uniq
      expect(assigned_reviewers).not_to include(reviewers.first.id)
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(VendorApplication).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      
      expect {
        described_class.auto_assign_reviewers(vendor_application)
      }.not_to raise_error
    end

    it 'handles email delivery failures' do
      allow(VendorApplicationMailer).to receive(:status_change_notification).and_raise(Net::SMTPError)
      
      expect {
        described_class.send_status_notification(vendor_application, 'submitted', 'under_review')
      }.not_to raise_error
    end

    it 'provides informative error messages' do
      result = described_class.calculate_application_score(nil, {})
      
      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end
end