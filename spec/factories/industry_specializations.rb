# frozen_string_literal: true

FactoryBot.define do
  factory :industry_specialization do
    association :festival
    
    industry_type { %w[technology healthcare manufacturing food_beverage arts automotive education tourism sports retail].sample }
    status { 'draft' }
    
    specialization_config do
      base_config = {
        booth_layout: "#{industry_type}_standard",
        equipment_requirements: ['basic_power', 'internet_access', 'display_space'],
        vendor_criteria: ['quality_standards', 'customer_reviews', 'industry_experience'],
        safety_protocols: ['general_safety', 'crowd_management'],
        certification_requirements: ['business_license', 'liability_insurance']
      }
      
      case industry_type
      when 'technology'
        base_config.merge(
          equipment_requirements: ['high_speed_internet', 'power_outlets', 'presentation_screens'],
          vendor_criteria: ['innovation_score', 'technical_expertise', 'product_maturity'],
          safety_protocols: ['electrical_safety', 'data_security'],
          certification_requirements: ['ISO_27001', 'privacy_compliance']
        )
      when 'healthcare'
        base_config.merge(
          equipment_requirements: ['medical_grade_power', 'clean_environment', 'privacy_partitions'],
          vendor_criteria: ['regulatory_compliance', 'safety_record', 'clinical_evidence'],
          safety_protocols: ['medical_safety', 'sanitation_protocols'],
          certification_requirements: ['FDA_approval', 'medical_device_certification']
        )
      when 'food_beverage'
        base_config.merge(
          equipment_requirements: ['commercial_kitchen_access', 'refrigeration', 'waste_disposal'],
          vendor_criteria: ['licensed_food_vendors', 'local_producers', 'specialty_beverages'],
          safety_protocols: ['food_safety', 'allergen_management'],
          certification_requirements: ['food_handling_license', 'health_department_approval']
        )
      else
        base_config
      end.to_json
    end
    
    compliance_requirements do
      base_compliance = {
        safety_standards: ['general_business_standards'],
        certifications: ['industry_certification', 'quality_assurance'],
        inspection_requirements: ['safety_inspection', 'compliance_check'],
        documentation: ['product_specifications', 'safety_documentation']
      }
      
      case industry_type
      when 'technology'
        base_compliance.merge(
          safety_standards: ['ISO_27001', 'GDPR_compliance'],
          certifications: ['cybersecurity_certification', 'product_certification'],
          inspection_requirements: ['security_audit', 'equipment_inspection'],
          documentation: ['technical_specifications', 'security_documentation']
        )
      when 'healthcare'
        base_compliance.merge(
          safety_standards: ['HIPAA', 'FDA_regulations'],
          certifications: ['medical_device_approval', 'quality_management_certification'],
          inspection_requirements: ['medical_device_inspection', 'facility_inspection'],
          documentation: ['clinical_data', 'regulatory_submissions']
        )
      when 'food_beverage'
        base_compliance.merge(
          safety_standards: ['HACCP', 'local_health_codes'],
          certifications: ['food_safety_certification', 'organic_certification'],
          inspection_requirements: ['health_inspection', 'kitchen_inspection'],
          documentation: ['ingredient_lists', 'nutritional_information']
        )
      else
        base_compliance
      end.to_json
    end
    
    specialized_metrics do
      base_metrics = {
        kpis: ['quality_rating', 'customer_satisfaction', 'vendor_performance'],
        targets: { quality_rating: 85, customer_satisfaction: 80, vendor_performance: 75 },
        completed_tasks: 0,
        total_tasks: 10,
        compliance_checklist: [
          { item: 'Business license verified', completed: false },
          { item: 'Insurance coverage confirmed', completed: false },
          { item: 'Safety protocols reviewed', completed: false }
        ]
      }
      
      case industry_type
      when 'technology'
        base_metrics.merge(
          kpis: ['innovation_index', 'tech_adoption_rate', 'developer_engagement'],
          targets: { innovation_index: 85, tech_adoption_rate: 70, developer_engagement: 60 },
          compliance_checklist: [
            { item: 'Data encryption implemented', completed: false },
            { item: 'Privacy policy reviewed', completed: false },
            { item: 'Security audit completed', completed: false }
          ]
        )
      when 'healthcare'
        base_metrics.merge(
          kpis: ['patient_outcomes', 'safety_score', 'regulatory_compliance_rate'],
          targets: { patient_outcomes: 95, safety_score: 98, regulatory_compliance_rate: 100 },
          compliance_checklist: [
            { item: 'Medical device approvals obtained', completed: false },
            { item: 'HIPAA compliance verified', completed: false },
            { item: 'Clinical documentation complete', completed: false }
          ]
        )
      when 'food_beverage'
        base_metrics.merge(
          kpis: ['food_safety_score', 'customer_satisfaction', 'local_sourcing_percentage'],
          targets: { food_safety_score: 95, customer_satisfaction: 90, local_sourcing_percentage: 40 },
          compliance_checklist: [
            { item: 'Health permits obtained', completed: false },
            { item: 'Food safety training completed', completed: false },
            { item: 'Allergen protocols established', completed: false }
          ]
        )
      else
        base_metrics
      end.to_json
    end
    
    # Timestamps
    activated_at { nil }
    completed_at { nil }
    
    trait :active do
      status { 'active' }
      activated_at { 1.week.ago }
    end
    
    trait :completed do
      status { 'completed' }
      activated_at { 1.month.ago }
      completed_at { 1.day.ago }
      
      specialized_metrics do
        base_metrics = {
          kpis: ['quality_rating', 'customer_satisfaction', 'vendor_performance'],
          targets: { quality_rating: 85, customer_satisfaction: 80, vendor_performance: 75 },
          completed_tasks: 10,
          total_tasks: 10,
          compliance_checklist: [
            { item: 'Business license verified', completed: true },
            { item: 'Insurance coverage confirmed', completed: true },
            { item: 'Safety protocols reviewed', completed: true }
          ]
        }
        
        case industry_type
        when 'technology'
          base_metrics.merge(
            kpis: ['innovation_index', 'tech_adoption_rate', 'developer_engagement'],
            targets: { innovation_index: 85, tech_adoption_rate: 70, developer_engagement: 60 },
            compliance_checklist: [
              { item: 'Data encryption implemented', completed: true },
              { item: 'Privacy policy reviewed', completed: true },
              { item: 'Security audit completed', completed: true }
            ]
          )
        when 'healthcare'
          base_metrics.merge(
            kpis: ['patient_outcomes', 'safety_score', 'regulatory_compliance_rate'],
            targets: { patient_outcomes: 95, safety_score: 98, regulatory_compliance_rate: 100 },
            compliance_checklist: [
              { item: 'Medical device approvals obtained', completed: true },
              { item: 'HIPAA compliance verified', completed: true },
              { item: 'Clinical documentation complete', completed: true }
            ]
          )
        when 'food_beverage'
          base_metrics.merge(
            kpis: ['food_safety_score', 'customer_satisfaction', 'local_sourcing_percentage'],
            targets: { food_safety_score: 95, customer_satisfaction: 90, local_sourcing_percentage: 40 },
            compliance_checklist: [
              { item: 'Health permits obtained', completed: true },
              { item: 'Food safety training completed', completed: true },
              { item: 'Allergen protocols established', completed: true }
            ]
          )
        else
          base_metrics
        end.to_json
      end
    end
    
    trait :technology do
      industry_type { 'technology' }
    end
    
    trait :healthcare do
      industry_type { 'healthcare' }
    end
    
    trait :food_beverage do
      industry_type { 'food_beverage' }
    end
  end
end