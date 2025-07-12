# frozen_string_literal: true

FactoryBot.define do
  factory :industry_specialization do
    association :festival
    
    industry_type { %w[technology healthcare manufacturing food_beverage arts automotive education tourism sports retail].sample }
    status { 'draft' }
    
    specialization_config do
      {
        booth_layout: "#{industry_type}_standard",
        equipment_requirements: equipment_requirements_for_industry,
        vendor_criteria: vendor_criteria_for_industry,
        safety_protocols: safety_protocols_for_industry,
        certification_requirements: certification_requirements_for_industry
      }.to_json
    end
    
    compliance_requirements do
      {
        safety_standards: compliance_standards_for_industry,
        certifications: required_certifications_for_industry,
        inspection_requirements: inspection_requirements_for_industry,
        documentation: required_documentation_for_industry
      }.to_json
    end
    
    specialized_metrics do
      {
        kpis: kpis_for_industry,
        targets: targets_for_industry,
        completed_tasks: 0,
        total_tasks: 10,
        compliance_checklist: compliance_checklist_for_industry
      }.to_json
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
        {
          kpis: kpis_for_industry,
          targets: targets_for_industry,
          completed_tasks: 10,
          total_tasks: 10,
          compliance_checklist: compliance_checklist_for_industry
        }.to_json
      end
    end
    
    trait :technology do
      industry_type { 'technology' }
      
      specialization_config do
        {
          booth_layout: 'tech_innovation_zone',
          equipment_requirements: ['high_speed_internet', 'power_outlets', 'presentation_screens'],
          vendor_criteria: ['tech_startup', 'established_tech_company', 'innovation_showcase'],
          safety_protocols: ['electrical_safety', 'data_security'],
          certification_requirements: ['ISO_27001', 'privacy_compliance']
        }.to_json
      end
    end
    
    trait :healthcare do
      industry_type { 'healthcare' }
      
      specialization_config do
        {
          booth_layout: 'healthcare_pavilion',
          equipment_requirements: ['medical_grade_power', 'clean_environment', 'privacy_partitions'],
          vendor_criteria: ['medical_device_companies', 'healthcare_services', 'wellness_providers'],
          safety_protocols: ['medical_safety', 'sanitation_protocols'],
          certification_requirements: ['FDA_approval', 'medical_device_certification']
        }.to_json
      end
    end
    
    trait :food_beverage do
      industry_type { 'food_beverage' }
      
      specialization_config do
        {
          booth_layout: 'culinary_marketplace',
          equipment_requirements: ['commercial_kitchen_access', 'refrigeration', 'waste_disposal'],
          vendor_criteria: ['licensed_food_vendors', 'local_producers', 'specialty_beverages'],
          safety_protocols: ['food_safety', 'allergen_management'],
          certification_requirements: ['food_handling_license', 'health_department_approval']
        }.to_json
      end
    end
    
    private
    
    def equipment_requirements_for_industry
      case industry_type
      when 'technology'
        ['wifi', 'power_outlets', 'display_screens']
      when 'healthcare'
        ['medical_grade_equipment', 'privacy_screens']
      when 'food_beverage'
        ['refrigeration', 'cooking_facilities', 'water_access']
      when 'automotive'
        ['vehicle_display_area', 'test_drive_space']
      when 'arts'
        ['display_lighting', 'security_systems', 'climate_control']
      else
        ['basic_power', 'internet_access', 'display_space']
      end
    end
    
    def vendor_criteria_for_industry
      case industry_type
      when 'technology'
        ['innovation_score', 'technical_expertise', 'product_maturity']
      when 'healthcare'
        ['regulatory_compliance', 'safety_record', 'clinical_evidence']
      when 'food_beverage'
        ['food_safety_rating', 'local_sourcing', 'menu_variety']
      else
        ['quality_standards', 'customer_reviews', 'industry_experience']
      end
    end
    
    def safety_protocols_for_industry
      case industry_type
      when 'technology'
        ['data_security', 'electrical_safety']
      when 'healthcare'
        ['infection_control', 'medical_safety']
      when 'food_beverage'
        ['food_safety', 'allergen_protocols']
      else
        ['general_safety', 'crowd_management']
      end
    end
    
    def certification_requirements_for_industry
      case industry_type
      when 'technology'
        ['ISO_27001', 'privacy_compliance']
      when 'healthcare'
        ['FDA_approval', 'medical_certification']
      when 'food_beverage'
        ['food_handler_license', 'health_permit']
      else
        ['business_license', 'liability_insurance']
      end
    end
    
    def compliance_standards_for_industry
      case industry_type
      when 'technology'
        ['ISO_27001', 'GDPR_compliance']
      when 'healthcare'
        ['HIPAA', 'FDA_regulations']
      when 'food_beverage'
        ['HACCP', 'local_health_codes']
      else
        ['general_business_standards']
      end
    end
    
    def required_certifications_for_industry
      case industry_type
      when 'technology'
        ['cybersecurity_certification', 'product_certification']
      when 'healthcare'
        ['medical_device_approval', 'quality_management_certification']
      when 'food_beverage'
        ['food_safety_certification', 'organic_certification']
      else
        ['industry_certification', 'quality_assurance']
      end
    end
    
    def inspection_requirements_for_industry
      case industry_type
      when 'technology'
        ['security_audit', 'equipment_inspection']
      when 'healthcare'
        ['medical_device_inspection', 'facility_inspection']
      when 'food_beverage'
        ['health_inspection', 'kitchen_inspection']
      else
        ['safety_inspection', 'compliance_check']
      end
    end
    
    def required_documentation_for_industry
      case industry_type
      when 'technology'
        ['technical_specifications', 'security_documentation']
      when 'healthcare'
        ['clinical_data', 'regulatory_submissions']
      when 'food_beverage'
        ['ingredient_lists', 'nutritional_information']
      else
        ['product_specifications', 'safety_documentation']
      end
    end
    
    def kpis_for_industry
      case industry_type
      when 'technology'
        ['innovation_index', 'tech_adoption_rate', 'developer_engagement']
      when 'healthcare'
        ['patient_outcomes', 'safety_score', 'regulatory_compliance_rate']
      when 'food_beverage'
        ['food_safety_score', 'customer_satisfaction', 'local_sourcing_percentage']
      else
        ['quality_rating', 'customer_satisfaction', 'vendor_performance']
      end
    end
    
    def targets_for_industry
      case industry_type
      when 'technology'
        { innovation_index: 85, tech_adoption_rate: 70, developer_engagement: 60 }
      when 'healthcare'
        { patient_outcomes: 95, safety_score: 98, regulatory_compliance_rate: 100 }
      when 'food_beverage'
        { food_safety_score: 95, customer_satisfaction: 90, local_sourcing_percentage: 40 }
      else
        { quality_rating: 85, customer_satisfaction: 80, vendor_performance: 75 }
      end
    end
    
    def compliance_checklist_for_industry
      case industry_type
      when 'technology'
        [
          { item: 'Data encryption implemented', completed: false },
          { item: 'Privacy policy reviewed', completed: false },
          { item: 'Security audit completed', completed: false }
        ]
      when 'healthcare'
        [
          { item: 'Medical device approvals obtained', completed: false },
          { item: 'HIPAA compliance verified', completed: false },
          { item: 'Clinical documentation complete', completed: false }
        ]
      when 'food_beverage'
        [
          { item: 'Health permits obtained', completed: false },
          { item: 'Food safety training completed', completed: false },
          { item: 'Allergen protocols established', completed: false }
        ]
      else
        [
          { item: 'Business license verified', completed: false },
          { item: 'Insurance coverage confirmed', completed: false },
          { item: 'Safety protocols reviewed', completed: false }
        ]
      end
    end
  end
end