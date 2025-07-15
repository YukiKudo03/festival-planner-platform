require 'rails_helper'

RSpec.describe ApplicationTemplate, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival) }
  let(:template) { create(:application_template, created_by: user, festival: festival) }

  describe 'associations' do
    it { should belong_to(:created_by).class_name('User') }
    it { should belong_to(:festival).optional }
    it { should have_many(:template_sections).dependent(:destroy) }
    it { should have_many(:template_fields).through(:template_sections) }
    it { should have_many(:vendor_applications).dependent(:nullify) }
    it { should have_many_attached(:template_file) }
    it { should have_many_attached(:sample_documents) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:template_type) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:version_number) }
    
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(1000) }
    
    context 'uniqueness validations' do
      before { template }
      
      it { should validate_uniqueness_of(:name).scoped_to(:festival_id, :template_type) }
    end
  end

  describe 'enums' do
    it 'defines template_type enum' do
      expect(ApplicationTemplate.template_types).to include(
        'application_form', 'business_license', 'vendor_agreement', 'guidelines', 'faq'
      )
    end

    it 'defines status enum' do
      expect(ApplicationTemplate.statuses).to include(
        'draft', 'active', 'archived', 'deprecated'
      )
    end
  end

  describe 'scopes' do
    let!(:active_template) { create(:application_template, status: :active) }
    let!(:draft_template) { create(:application_template, status: :draft) }
    let!(:global_template) { create(:application_template, :global_template) }

    describe '.active' do
      it 'returns only active templates' do
        expect(ApplicationTemplate.active).to include(active_template)
        expect(ApplicationTemplate.active).not_to include(draft_template)
      end
    end

    describe '.by_type' do
      let!(:form_template) { create(:application_template, template_type: :application_form) }
      let!(:license_template) { create(:application_template, template_type: :business_license) }

      it 'filters by template type' do
        expect(ApplicationTemplate.by_type(:application_form)).to include(form_template)
        expect(ApplicationTemplate.by_type(:application_form)).not_to include(license_template)
      end
    end

    describe '.global_templates' do
      it 'returns templates without festival association' do
        expect(ApplicationTemplate.global_templates).to include(global_template)
        expect(ApplicationTemplate.global_templates).not_to include(active_template)
      end
    end

    describe '.for_festival' do
      it 'returns templates for specific festival' do
        expect(ApplicationTemplate.for_festival(festival)).to include(template)
        expect(ApplicationTemplate.for_festival(festival)).not_to include(global_template)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :set_template_code' do
      it 'sets template code before creation' do
        new_template = build(:application_template)
        expect(new_template.template_code).to be_nil
        
        new_template.save!
        expect(new_template.template_code).to be_present
        expect(new_template.template_code).to match(/^TPL\d{4}[A-Z]{3}\d{3}$/)
      end
    end

    describe 'after_create :create_default_sections' do
      it 'creates default sections after template creation' do
        new_template = create(:application_template, template_type: :application_form)
        
        expect(new_template.template_sections.count).to be > 0
        expect(new_template.template_sections.pluck(:name)).to include('基本情報')
      end
    end
  end

  describe 'instance methods' do
    describe '#render_content' do
      let(:template_with_variables) do
        create(:application_template, content: "Festival: {{festival_name}}\nDate: {{current_date}}")
      end

      it 'renders content with variable substitution' do
        variables = { 'festival_name' => 'Test Festival', 'current_date' => '2024-01-01' }
        
        rendered = template_with_variables.render_content(variables)
        
        expect(rendered).to include('Festival: Test Festival')
        expect(rendered).to include('Date: 2024-01-01')
      end

      it 'handles missing variables gracefully' do
        variables = { 'festival_name' => 'Test Festival' }
        
        rendered = template_with_variables.render_content(variables)
        
        expect(rendered).to include('Festival: Test Festival')
        expect(rendered).to include('Date: {{current_date}}')
      end
    end

    describe '#clone_template' do
      let(:original_template) { create(:application_template, :with_sections) }

      it 'creates a copy of the template' do
        cloned = original_template.clone_template(name: 'Cloned Template')
        
        expect(cloned).to be_persisted
        expect(cloned.name).to eq('Cloned Template')
        expect(cloned.content).to eq(original_template.content)
        expect(cloned.template_type).to eq(original_template.template_type)
        expect(cloned.version_number).to eq(1)
      end

      it 'copies template sections' do
        cloned = original_template.clone_template(name: 'Cloned Template')
        
        expect(cloned.template_sections.count).to eq(original_template.template_sections.count)
      end
    end

    describe '#create_new_version' do
      it 'creates a new version of the template' do
        new_version = template.create_new_version(content: 'Updated content')
        
        expect(new_version).to be_persisted
        expect(new_version.version_number).to eq(template.version_number + 1)
        expect(new_version.content).to eq('Updated content')
        expect(new_version.parent_template_id).to eq(template.id)
      end

      it 'deprecates the current version' do
        template.create_new_version(content: 'Updated content')
        
        template.reload
        expect(template.status).to eq('deprecated')
      end
    end

    describe '#generate_pdf' do
      let(:template_with_content) do
        create(:application_template, content: "# Test Template\n\nThis is a test.")
      end

      it 'generates PDF from template content' do
        pdf_data = template_with_content.generate_pdf
        
        expect(pdf_data).to be_present
        expect(pdf_data).to start_with('%PDF')
      end

      it 'generates PDF with variables' do
        variables = { 'festival_name' => 'Test Festival' }
        pdf_data = template_with_content.generate_pdf(variables)
        
        expect(pdf_data).to be_present
      end
    end

    describe '#available_variables' do
      it 'returns list of available template variables' do
        variables = template.available_variables
        
        expect(variables).to include('festival_name', 'current_date', 'current_year')
        expect(variables).to be_an(Array)
      end
    end

    describe '#usage_count' do
      it 'returns the number of vendor applications using this template' do
        create_list(:vendor_application, 3, application_template: template)
        
        expect(template.usage_count).to eq(3)
      end
    end

    describe '#can_be_deleted?' do
      it 'returns true for unused templates' do
        expect(template.can_be_deleted?).to be true
      end

      it 'returns false for templates in use' do
        create(:vendor_application, application_template: template)
        
        expect(template.can_be_deleted?).to be false
      end
    end

    describe '#activate!' do
      let(:draft_template) { create(:application_template, status: :draft) }

      it 'activates a draft template' do
        expect { draft_template.activate! }.to change { draft_template.status }.to('active')
      end

      it 'sets activated_at timestamp' do
        draft_template.activate!
        
        expect(draft_template.activated_at).to be_present
        expect(draft_template.activated_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#archive!' do
      let(:active_template) { create(:application_template, status: :active) }

      it 'archives an active template' do
        expect { active_template.archive! }.to change { active_template.status }.to('archived')
      end

      it 'sets archived_at timestamp' do
        active_template.archive!
        
        expect(active_template.archived_at).to be_present
        expect(active_template.archived_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe 'class methods' do
    describe '.create_from_template' do
      it 'creates a new template from existing template' do
        new_template = ApplicationTemplate.create_from_template(
          template,
          name: 'New Template',
          festival: festival
        )
        
        expect(new_template).to be_persisted
        expect(new_template.name).to eq('New Template')
        expect(new_template.festival).to eq(festival)
      end
    end

    describe '.search' do
      let!(:searchable_template) { create(:application_template, name: 'Vendor Application Form') }

      it 'searches templates by name' do
        results = ApplicationTemplate.search('Vendor')
        
        expect(results).to include(searchable_template)
      end

      it 'searches templates by description' do
        template_with_desc = create(:application_template, description: 'Special vendor form')
        results = ApplicationTemplate.search('Special')
        
        expect(results).to include(template_with_desc)
      end
    end

    describe '.latest_versions' do
      let!(:v1_template) { create(:application_template, version_number: 1) }
      let!(:v2_template) { create(:application_template, version_number: 2, parent_template_id: v1_template.id) }

      it 'returns only the latest versions' do
        latest = ApplicationTemplate.latest_versions
        
        expect(latest).to include(v2_template)
        expect(latest).not_to include(v1_template)
      end
    end
  end

  describe 'file attachments' do
    it 'can attach template files' do
      template.template_file.attach(
        io: StringIO.new('template content'),
        filename: 'template.pdf',
        content_type: 'application/pdf'
      )
      
      expect(template.template_file).to be_attached
    end

    it 'can attach multiple sample documents' do
      template.sample_documents.attach([
        {
          io: StringIO.new('sample 1'),
          filename: 'sample1.pdf',
          content_type: 'application/pdf'
        },
        {
          io: StringIO.new('sample 2'),
          filename: 'sample2.pdf',
          content_type: 'application/pdf'
        }
      ])
      
      expect(template.sample_documents.count).to eq(2)
    end
  end
end