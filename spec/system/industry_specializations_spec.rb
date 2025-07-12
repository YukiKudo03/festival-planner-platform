# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Industry Specializations System', type: :system do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  
  before do
    sign_in user
  end

  describe 'Industry Specializations Index' do
    let!(:tech_specialization) { create(:industry_specialization, :technology, :active, festival: festival) }
    let!(:healthcare_specialization) { create(:industry_specialization, :healthcare, festival: festival) }
    
    it 'displays all festival specializations' do
      visit festival_industry_specializations_path(festival)
      
      expect(page).to have_content('Industry Specializations')
      expect(page).to have_content('Technology')
      expect(page).to have_content('Healthcare')
    end
    
    it 'shows specialization status badges' do
      visit festival_industry_specializations_path(festival)
      
      within('.specialization-list') do
        expect(page).to have_css('.status-badge.active')
        expect(page).to have_css('.status-badge.draft')
      end
    end
    
    it 'displays progress indicators' do
      visit festival_industry_specializations_path(festival)
      
      expect(page).to have_css('.progress-bar')
      expect(page).to have_content('Progress')
    end
    
    it 'filters by industry type' do
      visit festival_industry_specializations_path(festival)
      
      select 'Technology', from: 'Industry Type'
      click_button 'Filter'
      
      expect(page).to have_content('Technology')
      expect(page).not_to have_content('Healthcare')
    end
    
    it 'filters by status' do
      visit festival_industry_specializations_path(festival)
      
      select 'Active', from: 'Status'
      click_button 'Filter'
      
      expect(page).to have_css('.status-badge.active')
      expect(page).not_to have_css('.status-badge.draft')
    end
  end

  describe 'Creating Industry Specializations' do
    it 'creates a new technology specialization' do
      visit festival_industry_specializations_path(festival)
      
      click_link 'New Industry Specialization'
      
      select 'Technology', from: 'Industry Type'
      
      # Configure specialization settings
      within('.specialization-config') do
        select 'Tech Innovation Zone', from: 'Booth Layout'
        check 'High Speed Internet'
        check 'Power Outlets'
        check 'Presentation Screens'
      end
      
      # Set compliance requirements
      within('.compliance-requirements') do
        check 'ISO 27001'
        check 'Privacy Compliance'
        fill_in 'Additional Requirements', with: 'Data encryption protocols'
      end
      
      # Define specialized metrics
      within('.specialized-metrics') do
        fill_in 'Innovation Index Target', with: '85'
        fill_in 'Tech Adoption Rate Target', with: '70'
        fill_in 'Developer Engagement Target', with: '60'
      end
      
      click_button 'Create Industry Specialization'
      
      expect(page).to have_content('Industry specialization was successfully created')
      expect(page).to have_content('Technology')
      expect(page).to have_content('Draft')
    end
    
    it 'creates a healthcare specialization with specific requirements' do
      visit festival_industry_specializations_path(festival)
      
      click_link 'New Industry Specialization'
      
      select 'Healthcare', from: 'Industry Type'
      
      within('.specialization-config') do
        select 'Healthcare Pavilion', from: 'Booth Layout'
        check 'Medical Grade Power'
        check 'Clean Environment'
        check 'Privacy Partitions'
      end
      
      within('.compliance-requirements') do
        check 'FDA Approval'
        check 'Medical Device Certification'
        check 'HIPAA Compliance'
      end
      
      click_button 'Create Industry Specialization'
      
      expect(page).to have_content('Healthcare')
      expect(page).to have_content('Medical Grade Power')
    end
    
    it 'validates required fields' do
      visit festival_industry_specializations_path(festival)
      
      click_link 'New Industry Specialization'
      click_button 'Create Industry Specialization'
      
      expect(page).to have_content('Industry type can\'t be blank')
      expect(page).to have_content('Specialization config can\'t be blank')
    end
  end

  describe 'Viewing Industry Specialization Details' do
    let(:specialization) { create(:industry_specialization, :technology, :active, festival: festival) }
    
    it 'displays comprehensive specialization information' do
      visit festival_industry_specialization_path(festival, specialization)
      
      expect(page).to have_content('Technology Specialization')
      expect(page).to have_content('Active')
      expect(page).to have_content('Configuration Details')
      expect(page).to have_content('Compliance Requirements')
      expect(page).to have_content('Specialized Metrics')
    end
    
    it 'shows configuration settings' do
      visit festival_industry_specialization_path(festival, specialization)
      
      within('.configuration-section') do
        expect(page).to have_content('Booth Layout')
        expect(page).to have_content('Equipment Requirements')
        expect(page).to have_content('Vendor Criteria')
        expect(page).to have_content('Safety Protocols')
      end
    end
    
    it 'displays compliance checklist' do
      visit festival_industry_specialization_path(festival, specialization)
      
      within('.compliance-section') do
        expect(page).to have_content('Compliance Checklist')
        expect(page).to have_css('.compliance-item')
        expect(page).to have_css('.compliance-status')
      end
    end
    
    it 'shows progress metrics and KPIs' do
      visit festival_industry_specialization_path(festival, specialization)
      
      within('.metrics-section') do
        expect(page).to have_content('Progress Metrics')
        expect(page).to have_content('KPIs')
        expect(page).to have_content('Targets')
        expect(page).to have_css('.metric-chart')
      end
    end
  end

  describe 'Editing Industry Specializations' do
    let(:specialization) { create(:industry_specialization, :technology, festival: festival) }
    
    it 'updates specialization configuration' do
      visit edit_festival_industry_specialization_path(festival, specialization)
      
      within('.specialization-config') do
        check 'AR/VR Demo Area'
        fill_in 'Custom Equipment', with: 'Virtual reality headsets'
      end
      
      click_button 'Update Industry Specialization'
      
      expect(page).to have_content('Industry specialization was successfully updated')
      expect(page).to have_content('AR/VR Demo Area')
    end
    
    it 'modifies compliance requirements' do
      visit edit_festival_industry_specialization_path(festival, specialization)
      
      within('.compliance-requirements') do
        check 'Additional Security Certification'
        fill_in 'Compliance Notes', with: 'Enhanced security protocols required'
      end
      
      click_button 'Update Industry Specialization'
      
      expect(page).to have_content('Additional Security Certification')
    end
    
    it 'updates specialized metrics and targets' do
      visit edit_festival_industry_specialization_path(festival, specialization)
      
      within('.specialized-metrics') do
        fill_in 'Innovation Index Target', with: '90'
        fill_in 'New KPI', with: 'Startup Participation Rate'
        fill_in 'New Target', with: '75'
      end
      
      click_button 'Update Industry Specialization'
      
      expect(page).to have_content('90')
      expect(page).to have_content('Startup Participation Rate')
    end
  end

  describe 'Specialization Workflow Management' do
    let(:specialization) { create(:industry_specialization, festival: festival) }
    
    it 'activates a draft specialization' do
      visit festival_industry_specialization_path(festival, specialization)
      
      expect(page).to have_content('Draft')
      
      click_button 'Activate Specialization'
      
      expect(page).to have_content('Industry specialization activated successfully')
      expect(page).to have_content('Active')
      expect(page).to have_content('Activated on')
    end
    
    it 'completes an active specialization' do
      specialization.update!(status: 'active', activated_at: 1.week.ago)
      
      visit festival_industry_specialization_path(festival, specialization)
      
      click_button 'Complete Specialization'
      
      expect(page).to have_content('Industry specialization completed successfully')
      expect(page).to have_content('Completed')
      expect(page).to have_content('Completed on')
    end
    
    it 'prevents invalid status transitions' do
      visit festival_industry_specialization_path(festival, specialization)
      
      # Draft specializations cannot be completed directly
      expect(page).not_to have_button('Complete Specialization')
    end
  end

  describe 'Industry Dashboard' do
    let(:specialization) { create(:industry_specialization, :technology, :active, festival: festival) }
    
    it 'displays comprehensive industry analytics' do
      visit industry_dashboard_festival_industry_specialization_path(festival, specialization)
      
      expect(page).to have_content('Technology Industry Dashboard')
      expect(page).to have_content('Progress Overview')
      expect(page).to have_content('Compliance Status')
      expect(page).to have_content('Performance Metrics')
    end
    
    it 'shows progress percentage and completion status' do
      visit industry_dashboard_festival_industry_specialization_path(festival, specialization)
      
      within('.progress-overview') do
        expect(page).to have_css('.progress-circle')
        expect(page).to have_content('% Complete')
        expect(page).to have_content('Tasks Completed')
      end
    end
    
    it 'displays compliance score and requirements status' do
      visit industry_dashboard_festival_industry_specialization_path(festival, specialization)
      
      within('.compliance-status') do
        expect(page).to have_content('Compliance Score')
        expect(page).to have_css('.compliance-meter')
        expect(page).to have_content('Requirements Met')
      end
    end
    
    it 'shows specialized KPI metrics' do
      visit industry_dashboard_festival_industry_specialization_path(festival, specialization)
      
      within('.performance-metrics') do
        expect(page).to have_content('Innovation Index')
        expect(page).to have_content('Tech Adoption Rate')
        expect(page).to have_content('Developer Engagement')
        expect(page).to have_css('.kpi-chart')
      end
    end
    
    it 'provides actionable recommendations' do
      visit industry_dashboard_festival_industry_specialization_path(festival, specialization)
      
      within('.recommendations-section') do
        expect(page).to have_content('Recommendations')
        expect(page).to have_css('.recommendation-card')
        expect(page).to have_content('Priority Actions')
      end
    end
  end

  describe 'Metrics Management' do
    let(:specialization) { create(:industry_specialization, :technology, :active, festival: festival) }
    
    it 'updates specialized metrics' do
      visit festival_industry_specialization_path(festival, specialization)
      
      click_link 'Update Metrics'
      
      fill_in 'Leads Generated', with: '45'
      fill_in 'Conversion Rate', with: '12.5'
      fill_in 'Completed Tasks', with: '8'
      
      click_button 'Update Metrics'
      
      expect(page).to have_content('Metrics updated successfully')
      expect(page).to have_content('45')
      expect(page).to have_content('12.5')
    end
    
    it 'validates metric values' do
      visit festival_industry_specialization_path(festival, specialization)
      
      click_link 'Update Metrics'
      
      fill_in 'Conversion Rate', with: '-5'
      click_button 'Update Metrics'
      
      expect(page).to have_content('Conversion rate must be positive')
    end
    
    it 'tracks metric history and trends' do
      visit festival_industry_specialization_path(festival, specialization)
      
      click_link 'Metrics History'
      
      expect(page).to have_content('Metrics History')
      expect(page).to have_css('.metrics-timeline')
      expect(page).to have_css('.trend-chart')
    end
  end

  describe 'Compliance Management' do
    let(:specialization) { create(:industry_specialization, :healthcare, festival: festival) }
    
    it 'manages compliance checklist items' do
      visit festival_industry_specialization_path(festival, specialization)
      
      within('.compliance-checklist') do
        check 'Medical device approvals obtained'
        check 'HIPAA compliance verified'
        
        click_button 'Update Compliance'
      end
      
      expect(page).to have_content('Compliance updated successfully')
      expect(page).to have_css('.compliance-item.completed')
    end
    
    it 'tracks compliance progress' do
      visit festival_industry_specialization_path(festival, specialization)
      
      within('.compliance-progress') do
        expect(page).to have_content('Compliance Progress')
        expect(page).to have_css('.compliance-bar')
        expect(page).to have_content('% Complete')
      end
    end
    
    it 'displays compliance deadlines and alerts' do
      visit festival_industry_specialization_path(festival, specialization)
      
      within('.compliance-alerts') do
        expect(page).to have_content('Upcoming Deadlines')
        expect(page).to have_css('.deadline-alert')
        expect(page).to have_content('Days Remaining')
      end
    end
  end

  describe 'Industry Type Specific Features' do
    it 'shows technology-specific configuration options' do
      visit new_festival_industry_specialization_path(festival)
      
      select 'Technology', from: 'Industry Type'
      
      within('.industry-specific-config') do
        expect(page).to have_content('Innovation Zones')
        expect(page).to have_content('Demo Areas')
        expect(page).to have_content('Networking Spaces')
        expect(page).to have_content('Startup Showcases')
      end
    end
    
    it 'displays healthcare-specific requirements' do
      visit new_festival_industry_specialization_path(festival)
      
      select 'Healthcare', from: 'Industry Type'
      
      within('.industry-specific-config') do
        expect(page).to have_content('Medical Device Areas')
        expect(page).to have_content('Clinical Demonstration Zones')
        expect(page).to have_content('Privacy Compliant Spaces')
        expect(page).to have_content('Sanitization Stations')
      end
    end
    
    it 'shows food & beverage specific setup' do
      visit new_festival_industry_specialization_path(festival)
      
      select 'Food & Beverage', from: 'Industry Type'
      
      within('.industry-specific-config') do
        expect(page).to have_content('Commercial Kitchen Access')
        expect(page).to have_content('Refrigeration Units')
        expect(page).to have_content('Waste Management')
        expect(page).to have_content('Food Safety Stations')
      end
    end
  end

  describe 'Reporting and Analytics' do
    let!(:specializations) do
      [
        create(:industry_specialization, :technology, :completed, festival: festival),
        create(:industry_specialization, :healthcare, :active, festival: festival),
        create(:industry_specialization, :food_beverage, festival: festival)
      ]
    end
    
    it 'generates specialization summary report' do
      visit festival_industry_specializations_path(festival)
      
      click_link 'Generate Report'
      
      expect(page).to have_content('Industry Specializations Report')
      expect(page).to have_content('Summary Statistics')
      expect(page).to have_content('Completion Rates')
      expect(page).to have_content('Compliance Scores')
    end
    
    it 'exports specialization data' do
      visit festival_industry_specializations_path(festival)
      
      click_link 'Export Data'
      
      expect(page).to have_link('Export to CSV')
      expect(page).to have_link('Export to PDF')
      expect(page).to have_link('Export to Excel')
    end
    
    it 'displays performance analytics' do
      visit festival_industry_specializations_path(festival)
      
      click_link 'Analytics Dashboard'
      
      expect(page).to have_content('Performance Analytics')
      expect(page).to have_css('.analytics-chart')
      expect(page).to have_content('Industry Comparison')
      expect(page).to have_content('Trend Analysis')
    end
  end

  describe 'Error Handling and Validation' do
    it 'handles duplicate industry types gracefully' do
      create(:industry_specialization, :technology, festival: festival)
      
      visit new_festival_industry_specialization_path(festival)
      
      select 'Technology', from: 'Industry Type'
      click_button 'Create Industry Specialization'
      
      expect(page).to have_content('Industry type already exists for this festival')
    end
    
    it 'validates JSON configuration format' do
      visit new_festival_industry_specialization_path(festival)
      
      # Simulate invalid JSON input
      fill_in 'Specialization Config', with: 'invalid json format'
      click_button 'Create Industry Specialization'
      
      expect(page).to have_content('Invalid JSON format')
    end
    
    it 'shows helpful error messages for validation failures' do
      visit new_festival_industry_specialization_path(festival)
      
      click_button 'Create Industry Specialization'
      
      expect(page).to have_css('.error-message')
      expect(page).to have_content('Please correct the following errors')
    end
  end

  describe 'Mobile Responsiveness' do
    it 'displays properly on mobile devices', driver: :mobile do
      visit festival_industry_specializations_path(festival)
      
      expect(page).to have_css('.mobile-optimized')
      expect(page).to have_content('Industry Specializations')
      
      # Test mobile-specific navigation
      click_button 'Menu'
      expect(page).to have_css('.mobile-menu')
    end
    
    it 'adapts forms for mobile input', driver: :mobile do
      visit new_festival_industry_specialization_path(festival)
      
      expect(page).to have_css('.mobile-form')
      expect(page).to have_css('.touch-friendly-inputs')
    end
  end

  describe 'Accessibility' do
    it 'provides proper ARIA labels and keyboard navigation' do
      visit festival_industry_specializations_path(festival)
      
      expect(page).to have_css('[aria-label]')
      expect(page).to have_css('[role="button"]')
      expect(page).to have_css('[tabindex]')
    end
    
    it 'supports screen readers with descriptive content' do
      visit festival_industry_specializations_path(festival)
      
      expect(page).to have_css('.sr-only')
      expect(page).to have_content('Screen reader description')
    end
  end
end