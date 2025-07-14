class TemplateSection < ApplicationRecord
  belongs_to :application_template

  validates :name, presence: true, length: { maximum: 100 }
  validates :content, presence: true
  validates :order_index, presence: true, uniqueness: { scope: :application_template_id }

  scope :ordered, -> { order(:order_index) }
  scope :required_sections, -> { where(required: true) }
  scope :optional_sections, -> { where(required: false) }

  has_many :template_fields, dependent: :destroy

  def clone_for_template(target_template)
    new_section = self.dup
    new_section.application_template = target_template

    if new_section.save
      # フィールドもコピー
      template_fields.each do |field|
        field.clone_for_section(new_section)
      end
    end

    new_section
  end

  def render_content(variables = {})
    rendered_content = content.dup

    variables.each do |key, value|
      rendered_content.gsub!("{{#{key}}}", value.to_s)
    end

    rendered_content
  end

  def field_variables
    content.scan(/\{\{(\w+)\}\}/).flatten.uniq
  end
end
