require 'rails_helper'

RSpec.describe TemplateSection, type: :model do
  let(:template) { create(:application_template) }
  let(:section) { create(:template_section, application_template: template) }

  describe 'associations' do
    it { should belong_to(:application_template) }
    it { should have_many(:template_fields).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:section_type) }
    it { should validate_presence_of(:position) }
    
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(1000) }
    
    context 'uniqueness validations' do
      before { section }
      
      it { should validate_uniqueness_of(:position).scoped_to(:application_template_id) }
    end
  end

  describe 'enums' do
    it 'defines section_type enum' do
      expect(TemplateSection.section_types).to include(
        'information', 'business_details', 'documents', 'terms_agreement'
      )
    end
  end

  describe 'scopes' do
    let!(:required_section) { create(:template_section, required: true) }
    let!(:optional_section) { create(:template_section, required: false) }
    let!(:info_section) { create(:template_section, section_type: :information) }

    describe '.required' do
      it 'returns only required sections' do
        expect(TemplateSection.required).to include(required_section)
        expect(TemplateSection.required).not_to include(optional_section)
      end
    end

    describe '.optional' do
      it 'returns only optional sections' do
        expect(TemplateSection.optional).to include(optional_section)
        expect(TemplateSection.optional).not_to include(required_section)
      end
    end

    describe '.by_type' do
      it 'filters by section type' do
        expect(TemplateSection.by_type(:information)).to include(info_section)
      end
    end

    describe '.ordered' do
      let!(:section_1) { create(:template_section, position: 1) }
      let!(:section_3) { create(:template_section, position: 3) }
      let!(:section_2) { create(:template_section, position: 2) }

      it 'orders sections by position' do
        ordered = TemplateSection.ordered
        expect(ordered.first).to eq(section_1)
        expect(ordered.second).to eq(section_2)
        expect(ordered.third).to eq(section_3)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_position' do
      it 'sets position automatically if not provided' do
        new_section = build(:template_section, application_template: template, position: nil)
        new_section.save!
        
        expect(new_section.position).to be_present
        expect(new_section.position).to be > 0
      end

      it 'does not override existing position' do
        new_section = build(:template_section, application_template: template, position: 5)
        new_section.save!
        
        expect(new_section.position).to eq(5)
      end
    end
  end

  describe 'instance methods' do
    describe '#move_to_position' do
      let!(:section_1) { create(:template_section, application_template: template, position: 1) }
      let!(:section_2) { create(:template_section, application_template: template, position: 2) }
      let!(:section_3) { create(:template_section, application_template: template, position: 3) }

      it 'moves section to new position and adjusts others' do
        section_3.move_to_position(1)
        
        section_1.reload
        section_2.reload
        section_3.reload
        
        expect(section_3.position).to eq(1)
        expect(section_1.position).to eq(2)
        expect(section_2.position).to eq(3)
      end
    end

    describe '#field_count' do
      it 'returns the number of fields in the section' do
        create_list(:template_field, 3, template_section: section)
        
        expect(section.field_count).to eq(3)
      end
    end

    describe '#required_field_count' do
      it 'returns the number of required fields' do
        create_list(:template_field, 2, template_section: section, required: true)
        create(:template_field, template_section: section, required: false)
        
        expect(section.required_field_count).to eq(2)
      end
    end

    describe '#can_be_deleted?' do
      it 'returns true for sections without fields' do
        expect(section.can_be_deleted?).to be true
      end

      it 'returns false for sections with fields' do
        create(:template_field, template_section: section)
        
        expect(section.can_be_deleted?).to be false
      end
    end

    describe '#clone_to_template' do
      let(:target_template) { create(:application_template) }

      it 'creates a copy of the section in another template' do
        cloned = section.clone_to_template(target_template)
        
        expect(cloned).to be_persisted
        expect(cloned.application_template).to eq(target_template)
        expect(cloned.name).to eq(section.name)
        expect(cloned.section_type).to eq(section.section_type)
      end

      it 'copies template fields' do
        create_list(:template_field, 2, template_section: section)
        
        cloned = section.clone_to_template(target_template)
        
        expect(cloned.template_fields.count).to eq(2)
      end
    end

    describe '#should_display?' do
      context 'without display conditions' do
        it 'returns true' do
          expect(section.should_display?({})).to be true
        end
      end

      context 'with display conditions' do
        let(:conditional_section) do
          create(:template_section, :with_conditional_display)
        end

        it 'returns true when conditions are met' do
          form_data = { 'business_type' => 'food_service' }
          
          expect(conditional_section.should_display?(form_data)).to be true
        end

        it 'returns false when conditions are not met' do
          form_data = { 'business_type' => 'retail' }
          
          expect(conditional_section.should_display?(form_data)).to be false
        end
      end
    end

    describe '#validation_errors' do
      let(:section_with_fields) { create(:template_section, :with_fields) }

      it 'validates section data against field requirements' do
        form_data = {}
        errors = section_with_fields.validation_errors(form_data)
        
        expect(errors).to be_an(Array)
      end
    end
  end

  describe 'class methods' do
    describe '.create_default_sections' do
      let(:new_template) { create(:application_template) }

      it 'creates default sections for application_form template' do
        sections = TemplateSection.create_default_sections(new_template, :application_form)
        
        expect(sections).to be_an(Array)
        expect(sections.length).to be > 0
        expect(sections.map(&:name)).to include('基本情報')
      end

      it 'creates appropriate sections for each template type' do
        %i[application_form business_license vendor_agreement guidelines].each do |type|
          template = create(:application_template, template_type: type)
          sections = TemplateSection.create_default_sections(template, type)
          
          expect(sections).not_to be_empty
        end
      end
    end

    describe '.reorder_positions' do
      let!(:template) { create(:application_template) }
      let!(:section_a) { create(:template_section, application_template: template, position: 3) }
      let!(:section_b) { create(:template_section, application_template: template, position: 1) }
      let!(:section_c) { create(:template_section, application_template: template, position: 5) }

      it 'reorders sections to sequential positions' do
        TemplateSection.reorder_positions(template)
        
        section_a.reload
        section_b.reload
        section_c.reload
        
        positions = [section_a, section_b, section_c].sort_by(&:position).map(&:position)
        expect(positions).to eq([1, 2, 3])
      end
    end
  end

  describe 'JSON attributes' do
    it 'serializes display_conditions as JSON' do
      conditions = {
        'show_when' => {
          'field_name' => 'business_type',
          'operator' => 'equals',
          'value' => 'food_service'
        }
      }
      
      section.update!(display_conditions: conditions)
      section.reload
      
      expect(section.display_conditions).to eq(conditions)
    end

    it 'serializes validation_rules as JSON' do
      rules = {
        'required_fields' => ['business_name', 'contact_email'],
        'min_length' => { 'description' => 100 }
      }
      
      section.update!(validation_rules: rules)
      section.reload
      
      expect(section.validation_rules).to eq(rules)
    end
  end
end