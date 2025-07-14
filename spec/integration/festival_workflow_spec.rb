# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Festival Workflow Integration', type: :system do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, budget: 500000) }
  let(:venue) { create(:venue, capacity: 2000) }
  let(:municipal_authority) { create(:municipal_authority, :tourism_board) }

  before do
    festival.update!(venue: venue)
    sign_in user
  end

  describe 'Complete Festival Planning Workflow' do
    it 'creates and manages a complete festival with all integrations' do
      # Step 1: Create basic festival
      visit new_festival_path

      fill_in 'Festival Name', with: 'Tech Innovation Festival 2025'
      fill_in 'Description', with: 'A cutting-edge technology festival'
      fill_in 'Budget', with: '750000'
      select venue.name, from: 'Venue'
      fill_in 'Start Date', with: 3.months.from_now.strftime('%Y-%m-%d')
      fill_in 'End Date', with: (3.months.from_now + 3.days).strftime('%Y-%m-%d')

      click_button 'Create Festival'

      expect(page).to have_content('Festival was successfully created')
      expect(page).to have_content('Tech Innovation Festival 2025')

      # Step 2: Add Industry Specialization
      click_link 'Industry Specializations'
      click_link 'New Industry Specialization'

      select 'Technology', from: 'Industry Type'
      click_button 'Create Industry Specialization'

      expect(page).to have_content('Industry specialization was successfully created')

      # Activate specialization
      click_button 'Activate Specialization'
      expect(page).to have_content('Industry specialization activated successfully')

      # Step 3: Set up Tourism Collaboration
      click_link 'Tourism Collaborations'
      click_link 'New Tourism Collaboration'

      select municipal_authority.name, from: 'Municipal Authority'
      select 'Tourism Board', from: 'Collaboration Type'
      click_button 'Create Tourism Collaboration'

      expect(page).to have_content('Tourism collaboration was successfully created')

      # Approve collaboration
      click_button 'Approve Collaboration'
      expect(page).to have_content('Tourism collaboration approved successfully')

      # Activate collaboration
      click_button 'Activate Collaboration'
      expect(page).to have_content('Tourism collaboration activated successfully')

      # Step 4: Add Vendor Applications
      click_link 'Vendor Applications'
      click_link 'New Vendor Application'

      fill_in 'Business Name', with: 'TechCorp Inc.'
      fill_in 'Contact Email', with: 'contact@techcorp.com'
      select 'Technology Vendor', from: 'Vendor Type'
      click_button 'Submit Application'

      expect(page).to have_content('Vendor application submitted successfully')

      # Approve vendor application
      click_button 'Approve Application'
      expect(page).to have_content('Vendor application approved')

      # Step 5: Use AI Recommendations
      click_link 'AI Recommendations'

      # Get attendance prediction
      click_link 'Attendance Prediction'
      click_button 'Generate Prediction'
      expect(page).to have_content('Predicted Attendance')

      # Optimize layout
      click_link 'Layout Optimization'
      click_button 'Optimize Layout'
      expect(page).to have_content('Layout Optimization Results')

      # Get budget recommendations
      click_link 'Budget Allocation'
      click_button 'Generate Allocation'
      expect(page).to have_content('Recommended Budget Allocation')

      # Assess risks
      click_link 'Risk Assessment'
      click_button 'Assess Risks'
      expect(page).to have_content('Overall Risk Score')

      # Step 6: Create and manage tasks
      click_link 'Tasks'
      click_link 'New Task'

      fill_in 'Title', with: 'Set up technology demo area'
      fill_in 'Description', with: 'Prepare interactive technology demonstrations'
      select 'High', from: 'Priority'
      fill_in 'Due Date', with: 1.month.from_now.strftime('%Y-%m-%d')

      click_button 'Create Task'
      expect(page).to have_content('Task was successfully created')

      # Complete task
      click_button 'Mark Complete'
      expect(page).to have_content('Task completed successfully')

      # Step 7: Manage budget
      click_link 'Budget Management'

      # Add expense
      click_link 'New Expense'
      fill_in 'Description', with: 'Technology equipment rental'
      fill_in 'Amount', with: '25000'
      select 'Equipment', from: 'Category'
      click_button 'Create Expense'

      expect(page).to have_content('Expense was successfully created')

      # Add revenue
      click_link 'New Revenue'
      fill_in 'Description', with: 'Sponsorship from TechCorp'
      fill_in 'Amount', with: '50000'
      select 'Sponsorship', from: 'Category'
      click_button 'Create Revenue'

      expect(page).to have_content('Revenue was successfully created')

      # Step 8: Monitor progress with dashboard
      click_link 'Dashboard'

      expect(page).to have_content('Festival Dashboard')
      expect(page).to have_content('Budget Overview')
      expect(page).to have_content('Task Progress')
      expect(page).to have_content('Vendor Status')
      expect(page).to have_content('Industry Specialization Status')
      expect(page).to have_content('Tourism Collaboration Status')

      # Step 9: Generate reports
      click_link 'Reports'

      expect(page).to have_content('Festival Reports')
      expect(page).to have_link('Budget Report')
      expect(page).to have_link('Vendor Report')
      expect(page).to have_link('Industry Specialization Report')
      expect(page).to have_link('Tourism Impact Report')

      # Generate comprehensive report
      click_link 'Generate Comprehensive Report'
      expect(page).to have_content('Comprehensive Festival Report')
      expect(page).to have_content('Executive Summary')
      expect(page).to have_content('Financial Performance')
      expect(page).to have_content('Operational Metrics')
      expect(page).to have_content('Industry Specialization Performance')
      expect(page).to have_content('Tourism Collaboration Impact')
    end
  end

  describe 'Cross-Feature Integration' do
    let!(:industry_spec) { create(:industry_specialization, :technology, :active, festival: festival) }
    let!(:tourism_collab) { create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority) }
    let!(:vendor_apps) { create_list(:vendor_application, 3, festival: festival, status: 'approved') }

    it 'integrates AI recommendations with industry specialization data' do
      visit festival_ai_recommendations_path(festival)

      # AI should consider industry specialization context
      click_link 'Industry-Specific Analysis'

      expect(page).to have_content('Technology Industry Analysis')
      expect(page).to have_content('Industry-Specific Recommendations')
      expect(page).to have_content('Tech Vendor Optimization')
    end

    it 'correlates tourism collaboration data with budget planning' do
      visit festival_tourism_collaborations_path(festival)

      click_link tourism_collab.municipal_authority.name
      click_link 'Update Visitor Analytics'

      fill_in 'Total Visitors', with: '5000'
      fill_in 'Economic Impact', with: '250000'
      click_button 'Update Analytics'

      # Visit budget section to see tourism impact
      visit festival_path(festival)
      click_link 'Budget Analysis'

      expect(page).to have_content('Tourism Revenue Impact')
      expect(page).to have_content('$250,000')
    end

    it 'uses industry specialization criteria for vendor evaluation' do
      visit festival_vendor_applications_path(festival)

      within('.vendor-evaluation') do
        expect(page).to have_content('Industry Compliance Score')
        expect(page).to have_content('Technology Specialization Fit')
        expect(page).to have_content('Innovation Index')
      end
    end

    it 'integrates all metrics into unified dashboard' do
      visit festival_path(festival)

      within('.unified-dashboard') do
        # Industry metrics
        expect(page).to have_content('Industry Specialization Progress')
        expect(page).to have_content('Compliance Score')

        # Tourism metrics
        expect(page).to have_content('Tourism Collaboration Status')
        expect(page).to have_content('Economic Impact')

        # AI recommendations
        expect(page).to have_content('AI Insights')
        expect(page).to have_content('Optimization Recommendations')

        # Budget integration
        expect(page).to have_content('Budget Health')
        expect(page).to have_content('Financial Projections')
      end
    end
  end

  describe 'Data Flow and Consistency' do
    it 'maintains data consistency across all features' do
      # Create festival with all features
      industry_spec = create(:industry_specialization, :technology, :active, festival: festival)
      tourism_collab = create(:tourism_collaboration, :active, festival: festival, municipal_authority: municipal_authority)

      # Update industry metrics
      visit industry_dashboard_festival_industry_specialization_path(festival, industry_spec)

      click_link 'Update Metrics'
      fill_in 'Innovation Index', with: '88'
      click_button 'Update Metrics'

      # Update tourism analytics
      visit collaboration_dashboard_festival_tourism_collaboration_path(festival, tourism_collab)

      click_link 'Update Visitor Analytics'
      fill_in 'Total Visitors', with: '6000'
      click_button 'Update Analytics'

      # Check that AI recommendations reflect updated data
      visit festival_ai_recommendations_path(festival)
      click_link 'Predictive Dashboard'

      expect(page).to have_content('Innovation Index: 88')
      expect(page).to have_content('Projected Visitors: 6,000')

      # Verify dashboard shows consistent data
      visit festival_path(festival)

      within('.metrics-summary') do
        expect(page).to have_content('88') # Innovation index
        expect(page).to have_content('6,000') # Visitor count
      end
    end

    it 'propagates budget changes across all dependent calculations' do
      # Update festival budget
      visit edit_festival_path(festival)
      fill_in 'Budget', with: '1000000'
      click_button 'Update Festival'

      # Check AI budget recommendations update
      visit festival_ai_recommendations_path(festival)
      click_link 'Budget Allocation'
      click_button 'Generate Allocation'

      expect(page).to have_content('$1,000,000')

      # Check industry specialization budget consideration
      industry_spec = create(:industry_specialization, :technology, festival: festival)
      visit industry_dashboard_festival_industry_specialization_path(festival, industry_spec)

      expect(page).to have_content('Budget Allocation for Technology')
      expect(page).to have_content('$1,000,000') # Total budget reference
    end

    it 'maintains referential integrity when deleting related records' do
      industry_spec = create(:industry_specialization, :technology, festival: festival)
      tourism_collab = create(:tourism_collaboration, festival: festival, municipal_authority: municipal_authority)

      # Delete municipal authority
      municipal_authority.destroy

      visit festival_tourism_collaborations_path(festival)

      # Tourism collaboration should handle missing authority gracefully
      expect(page).to have_content('Municipal Authority: Deleted')
      expect(page).not_to raise_error
    end
  end

  describe 'Performance and Scalability' do
    before do
      # Create larger dataset for performance testing
      create_list(:industry_specialization, 5, festival: festival)
      create_list(:tourism_collaboration, 3, festival: festival)
      create_list(:vendor_application, 20, festival: festival, status: 'approved')
      create_list(:task, 50, festival: festival)
    end

    it 'loads dashboard efficiently with large datasets' do
      start_time = Time.current

      visit festival_path(festival)

      expect(page).to have_content('Festival Dashboard')

      load_time = Time.current - start_time
      expect(load_time).to be < 5.seconds # Performance threshold
    end

    it 'handles AI analysis with multiple specializations efficiently' do
      visit festival_ai_recommendations_path(festival)

      start_time = Time.current

      click_link 'Batch Analysis'
      click_button 'Run Batch Analysis'

      expect(page).to have_content('Batch Analysis Results')

      analysis_time = Time.current - start_time
      expect(analysis_time).to be < 10.seconds # Analysis threshold
    end

    it 'paginates large vendor lists properly' do
      visit festival_vendor_applications_path(festival)

      expect(page).to have_css('.pagination')
      expect(page).to have_content('20 vendors')

      # Test pagination navigation
      if page.has_link?('Next')
        click_link 'Next'
        expect(page).to have_content('Page 2')
      end
    end
  end

  describe 'Error Recovery and Resilience' do
    it 'handles AI service failures gracefully' do
      # Mock AI service failure
      allow_any_instance_of(AiRecommendationService).to receive(:predict_attendance)
        .and_raise(StandardError.new('AI service unavailable'))

      visit festival_ai_recommendations_path(festival)
      click_link 'Attendance Prediction'
      click_button 'Generate Prediction'

      expect(page).to have_content('Unable to generate prediction at this time')
      expect(page).to have_content('Please try again later')
      expect(page).not_to have_content('Error') # No raw error messages
    end

    it 'recovers from partial feature failures' do
      # Simulate industry specialization error
      allow_any_instance_of(IndustrySpecialization).to receive(:progress_percentage)
        .and_raise(StandardError.new('Calculation error'))

      visit festival_path(festival)

      # Dashboard should still load other metrics
      expect(page).to have_content('Festival Dashboard')
      expect(page).to have_content('Budget Overview')
      expect(page).to have_content('Vendor Status')

      # Industry section should show error state
      within('.industry-specialization-section') do
        expect(page).to have_content('Unable to load progress')
      end
    end

    it 'validates cross-feature data dependencies' do
      # Try to create tourism collaboration without municipal authority
      visit new_festival_tourism_collaboration_path(festival)

      select 'Tourism Board', from: 'Collaboration Type'
      click_button 'Create Tourism Collaboration'

      expect(page).to have_content('Municipal authority must be selected')
      expect(page).to render_template(:new)
    end
  end

  describe 'Security and Authorization Integration' do
    let(:other_user) { create(:user) }
    let(:other_festival) { create(:festival, user: other_user) }

    it 'enforces authorization across all festival features' do
      # User should not access other user's festival features
      visit festival_path(other_festival)
      expect(page).to have_current_path(root_path)

      visit festival_industry_specializations_path(other_festival)
      expect(page).to have_current_path(root_path)

      visit festival_tourism_collaborations_path(other_festival)
      expect(page).to have_current_path(root_path)

      visit festival_ai_recommendations_path(other_festival)
      expect(page).to have_current_path(root_path)
    end

    it 'maintains session security across feature navigation' do
      sign_out user

      visit festival_path(festival)
      expect(page).to have_current_path(new_user_session_path)

      visit festival_industry_specializations_path(festival)
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe 'Mobile Workflow Integration' do
    it 'provides complete workflow on mobile devices', driver: :mobile do
      visit festival_path(festival)

      expect(page).to have_css('.mobile-dashboard')

      # Test mobile navigation between features
      click_button 'Mobile Menu'

      within('.mobile-menu') do
        expect(page).to have_link('Industry Specializations')
        expect(page).to have_link('Tourism Collaborations')
        expect(page).to have_link('AI Recommendations')
        expect(page).to have_link('Vendors')
        expect(page).to have_link('Budget')
      end

      # Test mobile feature interaction
      click_link 'AI Recommendations'
      expect(page).to have_css('.mobile-ai-dashboard')

      click_link 'Quick Prediction'
      expect(page).to have_css('.mobile-prediction-form')
    end
  end
end
