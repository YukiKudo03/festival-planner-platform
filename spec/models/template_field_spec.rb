require 'rails_helper'

RSpec.describe TemplateField, type: :model do
  let(:template) { create(:application_template) }
  let(:section) { create(:template_section, application_template: template) }
  let(:field) { create(:template_field, template_section: section) }

  describe 'associations' do
    it { should belong_to(:template_section) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:label) }
    it { should validate_presence_of(:field_type) }
    it { should validate_presence_of(:position) }
    
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:label).is_at_most(255) }
    it { should validate_length_of(:help_text).is_at_most(1000) }
    
    context 'uniqueness validations' do
      before { field }
      
      it { should validate_uniqueness_of(:name).scoped_to(:template_section_id) }
      it { should validate_uniqueness_of(:position).scoped_to(:template_section_id) }
    end

    context 'name format validation' do
      it 'allows valid field names' do
        valid_names = %w[business_name contact_email expected_revenue]
        
        valid_names.each do |name|
          field = build(:template_field, name: name)
          expect(field).to be_valid
        end
      end

      it 'rejects invalid field names' do
        invalid_names = ['invalid name', 'invalid-name', '123invalid']
        
        invalid_names.each do |name|
          field = build(:template_field, name: name)
          expect(field).not_to be_valid
          expect(field.errors[:name]).to include('must be a valid field name (lowercase, underscores only)')
        end
      end
    end
  end

  describe 'enums' do
    it 'defines field_type enum' do
      expect(TemplateField.field_types).to include(
        'text', 'email', 'tel', 'url', 'number', 'date', 'datetime',
        'textarea', 'select', 'radio', 'checkbox', 'file'
      )
    end
  end

  describe 'scopes' do
    let!(:required_field) { create(:template_field, required: true) }
    let!(:optional_field) { create(:template_field, required: false) }
    let!(:text_field) { create(:template_field, field_type: :text) }

    describe '.required' do
      it 'returns only required fields' do
        expect(TemplateField.required).to include(required_field)
        expect(TemplateField.required).not_to include(optional_field)
      end
    end

    describe '.optional' do
      it 'returns only optional fields' do
        expect(TemplateField.optional).to include(optional_field)
        expect(TemplateField.optional).not_to include(required_field)
      end
    end

    describe '.by_type' do
      it 'filters by field type' do
        expect(TemplateField.by_type(:text)).to include(text_field)
      end
    end

    describe '.ordered' do
      let!(:field_1) { create(:template_field, position: 1) }
      let!(:field_3) { create(:template_field, position: 3) }
      let!(:field_2) { create(:template_field, position: 2) }

      it 'orders fields by position' do
        ordered = TemplateField.ordered
        expect(ordered.first).to eq(field_1)
        expect(ordered.second).to eq(field_2)
        expect(ordered.third).to eq(field_3)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_position' do
      it 'sets position automatically if not provided' do
        new_field = build(:template_field, template_section: section, position: nil)
        new_field.save!
        
        expect(new_field.position).to be_present
        expect(new_field.position).to be > 0
      end

      it 'does not override existing position' do
        new_field = build(:template_field, template_section: section, position: 5)
        new_field.save!
        
        expect(new_field.position).to eq(5)
      end
    end
  end

  describe 'instance methods' do
    describe '#move_to_position' do
      let!(:field_1) { create(:template_field, template_section: section, position: 1) }
      let!(:field_2) { create(:template_field, template_section: section, position: 2) }
      let!(:field_3) { create(:template_field, template_section: section, position: 3) }

      it 'moves field to new position and adjusts others' do
        field_3.move_to_position(1)
        
        field_1.reload
        field_2.reload
        field_3.reload
        
        expect(field_3.position).to eq(1)
        expect(field_1.position).to eq(2)
        expect(field_2.position).to eq(3)
      end
    end

    describe '#validate_value' do
      context 'with text field' do
        let(:text_field) { create(:template_field, :text_field) }

        it 'validates text length' do
          result = text_field.validate_value('a')
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(/too short/)
        end

        it 'validates pattern matching' do
          result = text_field.validate_value('Valid Business Name')
          expect(result[:valid]).to be true
        end
      end

      context 'with email field' do
        let(:email_field) { create(:template_field, :email_field) }

        it 'validates email format' do
          result = email_field.validate_value('invalid-email')
          expect(result[:valid]).to be false
          
          result = email_field.validate_value('test@example.com')
          expect(result[:valid]).to be true
        end
      end

      context 'with select field' do
        let(:select_field) { create(:template_field, :select_field) }

        it 'validates option selection' do
          result = select_field.validate_value('invalid_option')
          expect(result[:valid]).to be false
          
          result = select_field.validate_value('food_service')
          expect(result[:valid]).to be true
        end
      end

      context 'with number field' do
        let(:number_field) { create(:template_field, :number_field) }

        it 'validates numeric range' do
          result = number_field.validate_value(-100)
          expect(result[:valid]).to be false
          
          result = number_field.validate_value(1000000)
          expect(result[:valid]).to be true
        end
      end

      context 'with file field' do
        let(:file_field) { create(:template_field, :file_field) }

        it 'validates file type' do
          file = double('file', original_filename: 'test.exe')
          result = file_field.validate_value(file)
          expect(result[:valid]).to be false
          
          file = double('file', original_filename: 'test.pdf')
          result = file_field.validate_value(file)
          expect(result[:valid]).to be true
        end
      end
    end

    describe '#should_display?' do
      context 'without display conditions' do
        it 'returns true' do
          expect(field.should_display?({})).to be true
        end
      end

      context 'with display conditions' do
        let(:conditional_field) do
          create(:template_field, :with_conditional_logic)
        end

        it 'returns true when conditions are met' do
          form_data = { 'business_type' => 'food_service' }
          
          expect(conditional_field.should_display?(form_data)).to be true
        end

        it 'returns false when conditions are not met' do
          form_data = { 'business_type' => 'retail' }
          
          expect(conditional_field.should_display?(form_data)).to be false
        end
      end
    end

    describe '#html_input_type' do
      it 'returns correct HTML input types' do
        expect(build(:template_field, field_type: :text).html_input_type).to eq('text')
        expect(build(:template_field, field_type: :email).html_input_type).to eq('email')
        expect(build(:template_field, field_type: :tel).html_input_type).to eq('tel')
        expect(build(:template_field, field_type: :number).html_input_type).to eq('number')
        expect(build(:template_field, field_type: :date).html_input_type).to eq('date')
        expect(build(:template_field, field_type: :url).html_input_type).to eq('url')
      end

      it 'returns nil for non-input field types' do
        expect(build(:template_field, field_type: :textarea).html_input_type).to be_nil
        expect(build(:template_field, field_type: :select).html_input_type).to be_nil
      end
    end

    describe '#html_attributes' do
      it 'generates HTML attributes from field options and validation rules' do
        field = create(:template_field, :text_field)
        attributes = field.html_attributes
        
        expect(attributes).to include('maxlength' => 100)
        expect(attributes).to include('pattern')
        expect(attributes).to include('required' => true)
      end

      it 'includes placeholder from field options' do
        field = create(:template_field, :textarea_field)
        attributes = field.html_attributes
        
        expect(attributes).to include('placeholder')
      end
    end

    describe '#select_options' do
      let(:select_field) { create(:template_field, :select_field) }

      it 'returns formatted options for select fields' do
        options = select_field.select_options
        
        expect(options).to be_an(Array)
        expect(options.first).to have_key('value')
        expect(options.first).to have_key('label')
      end
    end

    describe '#clone_to_section' do
      let(:target_section) { create(:template_section) }

      it 'creates a copy of the field in another section' do
        cloned = field.clone_to_section(target_section)
        
        expect(cloned).to be_persisted
        expect(cloned.template_section).to eq(target_section)
        expect(cloned.name).to eq(field.name)
        expect(cloned.field_type).to eq(field.field_type)
      end
    end
  end

  describe 'class methods' do
    describe '.create_default_fields' do
      it 'creates default fields for information section' do
        fields = TemplateField.create_default_fields(section, :information)
        
        expect(fields).to be_an(Array)
        expect(fields.length).to be > 0
        expect(fields.map(&:name)).to include('business_name')
      end

      it 'creates appropriate fields for each section type' do
        %i[information business_details documents terms_agreement].each do |type|
          section = create(:template_section, section_type: type)
          fields = TemplateField.create_default_fields(section, type)
          
          expect(fields).not_to be_empty
        end
      end
    end

    describe '.reorder_positions' do
      let!(:field_a) { create(:template_field, template_section: section, position: 3) }
      let!(:field_b) { create(:template_field, template_section: section, position: 1) }
      let!(:field_c) { create(:template_field, template_section: section, position: 5) }

      it 'reorders fields to sequential positions' do
        TemplateField.reorder_positions(section)
        
        field_a.reload
        field_b.reload
        field_c.reload
        
        positions = [field_a, field_b, field_c].sort_by(&:position).map(&:position)
        expect(positions).to eq([1, 2, 3])
      end
    end

    describe '.field_type_options' do
      it 'returns available field types with labels' do
        options = TemplateField.field_type_options
        
        expect(options).to be_a(Hash)
        expect(options.keys).to include('text', 'email', 'select', 'textarea')
      end
    end
  end

  describe 'JSON attributes' do
    it 'serializes field_options as JSON' do
      options = {
        'options' => [
          { 'value' => 'option1', 'label' => 'Option 1' },
          { 'value' => 'option2', 'label' => 'Option 2' }
        ]
      }
      
      field.update!(field_options: options)
      field.reload
      
      expect(field.field_options).to eq(options)
    end

    it 'serializes validation_rules as JSON' do
      rules = {
        'min_length' => 10,
        'max_length' => 100,
        'pattern' => '^[A-Za-z ]+$'
      }
      
      field.update!(validation_rules: rules)
      field.reload
      
      expect(field.validation_rules).to eq(rules)
    end

    it 'serializes display_conditions as JSON' do
      conditions = {
        'show_when' => {
          'field_name' => 'business_type',
          'operator' => 'equals',
          'value' => 'retail'
        }
      }
      
      field.update!(display_conditions: conditions)
      field.reload
      
      expect(field.display_conditions).to eq(conditions)
    end
  end
end