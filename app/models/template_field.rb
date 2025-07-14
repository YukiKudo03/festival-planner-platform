class TemplateField < ApplicationRecord
  belongs_to :template_section

  validates :name, presence: true, length: { maximum: 100 }
  validates :field_type, presence: true, inclusion: {
    in: %w[text textarea number email date select checkbox radio file]
  }
  validates :order_index, presence: true, uniqueness: { scope: :template_section_id }

  enum field_type: {
    text: 0,
    textarea: 1,
    number: 2,
    email: 3,
    date: 4,
    select: 5,
    checkbox: 6,
    radio: 7,
    file: 8
  }

  scope :ordered, -> { order(:order_index) }
  scope :required_fields, -> { where(required: true) }

  def clone_for_section(target_section)
    new_field = self.dup
    new_field.template_section = target_section
    new_field.save
    new_field
  end

  def field_type_text
    case field_type
    when "text" then "テキスト"
    when "textarea" then "テキストエリア"
    when "number" then "数値"
    when "email" then "メールアドレス"
    when "date" then "日付"
    when "select" then "選択肢"
    when "checkbox" then "チェックボックス"
    when "radio" then "ラジオボタン"
    when "file" then "ファイル"
    else field_type.humanize
    end
  end

  def options_array
    return [] unless options.present?
    options.split("\n").map(&:strip).reject(&:blank?)
  end

  def validation_rules
    rules = []
    rules << "required" if required?
    rules << "maxlength:#{max_length}" if max_length.present?
    rules << "minlength:#{min_length}" if min_length.present?
    rules << "max:#{max_value}" if max_value.present?
    rules << "min:#{min_value}" if min_value.present?
    rules.join("|")
  end
end
