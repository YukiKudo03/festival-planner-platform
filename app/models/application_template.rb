class ApplicationTemplate < ApplicationRecord
  belongs_to :festival, optional: true
  belongs_to :created_by, class_name: "User"

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :template_type, presence: true, inclusion: {
    in: %w[application_form business_license vendor_agreement guidelines faq]
  }
  validates :content, presence: true

  enum status: {
    draft: 0,
    active: 1,
    archived: 2,
    deprecated: 3
  }

  enum template_type: {
    application_form: 0,
    business_license: 1,
    vendor_agreement: 2,
    guidelines: 3,
    faq: 4,
    checklist: 5,
    requirements: 6
  }

  scope :active_templates, -> { where(status: :active) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :for_festival, ->(festival) { where(festival: festival) }
  scope :global_templates, -> { where(festival: nil) }
  scope :recent, -> { order(updated_at: :desc) }

  # Active Storage attachments
  has_one_attached :template_file
  has_many_attached :sample_documents

  # 関連
  has_many :template_sections, dependent: :destroy
  has_many :template_fields, through: :template_sections
  has_many :vendor_applications_using_template,
           class_name: "VendorApplication",
           foreign_key: "application_template_id",
           dependent: :nullify

  before_create :set_version_number
  after_update :archive_previous_version, if: :major_content_change?

  def type_text
    case template_type
    when "application_form" then "申請フォーム"
    when "business_license" then "営業許可証"
    when "vendor_agreement" then "出店契約書"
    when "guidelines" then "ガイドライン"
    when "faq" then "よくある質問"
    when "checklist" then "チェックリスト"
    when "requirements" then "必要要件"
    else template_type.humanize
    end
  end

  def status_text
    case status
    when "draft" then "下書き"
    when "active" then "有効"
    when "archived" then "アーカイブ"
    when "deprecated" then "非推奨"
    else status.humanize
    end
  end

  def status_color
    case status
    when "draft" then "secondary"
    when "active" then "success"
    when "archived" then "info"
    when "deprecated" then "warning"
    else "secondary"
    end
  end

  def can_be_edited_by?(user)
    return true if user.admin? || user.system_admin?
    return true if user.committee_member? && festival&.users&.include?(user)
    created_by == user
  end

  def can_be_used_by?(user, application_festival = nil)
    return false unless active?

    # グローバルテンプレートは誰でも使用可能
    return true if festival.nil?

    # 祭り固有のテンプレートは該当祭りの関係者のみ
    return false if application_festival && festival != application_festival

    festival.users.include?(user) || user.admin? || user.system_admin?
  end

  def render_content(variables = {})
    rendered_content = content.dup

    # 変数の置換
    variables.each do |key, value|
      rendered_content.gsub!("{{#{key}}}", value.to_s)
    end

    # 標準変数の置換
    standard_variables.each do |key, value|
      rendered_content.gsub!("{{#{key}}}", value.to_s)
    end

    rendered_content
  end

  def generate_pdf(variables = {})
    rendered_content = render_content(variables)

    # PDF生成ロジック（WickedPDFやPrawnを使用）
    # 簡略化した例
    {
      content: rendered_content,
      filename: "#{name.parameterize}_#{Time.current.strftime('%Y%m%d')}.pdf"
    }
  end

  def clone_for_festival(target_festival, user)
    new_template = self.dup
    new_template.festival = target_festival
    new_template.created_by = user
    new_template.name = "#{name} (#{target_festival.name}用)"
    new_template.status = :draft
    new_template.version_number = 1
    new_template.cloned_from_id = id

    if new_template.save
      # セクションもコピー
      template_sections.each do |section|
        section.clone_for_template(new_template)
      end
    end

    new_template
  end

  def usage_statistics
    {
      total_applications: vendor_applications_using_template.count,
      active_applications: vendor_applications_using_template.where.not(status: [ :withdrawn, :cancelled ]).count,
      approval_rate: calculate_approval_rate,
      last_used: vendor_applications_using_template.maximum(:created_at),
      popular_sections: calculate_popular_sections
    }
  end

  def validation_errors_summary
    applications = vendor_applications_using_template.includes(:application_reviews)

    common_issues = {}
    applications.each do |app|
      app.application_reviews.where(action: :requested_changes).each do |review|
        next unless review.comment.present?

        # コメントから共通の問題を抽出（簡単な実装）
        review.comment.scan(/\b\w+\b/).each do |word|
          common_issues[word] ||= 0
          common_issues[word] += 1
        end
      end
    end

    common_issues.sort_by { |word, count| -count }.first(10)
  end

  def self.create_default_templates(festival = nil)
    templates = []

    # 申請フォームテンプレート
    templates << create!(
      name: "基本出店申請フォーム",
      template_type: :application_form,
      festival: festival,
      created_by: User.first, # 適切なユーザーに変更
      content: default_application_form_content,
      status: :active
    )

    # ガイドラインテンプレート
    templates << create!(
      name: "出店ガイドライン",
      template_type: :guidelines,
      festival: festival,
      created_by: User.first,
      content: default_guidelines_content,
      status: :active
    )

    # FAQテンプレート
    templates << create!(
      name: "よくある質問",
      template_type: :faq,
      festival: festival,
      created_by: User.first,
      content: default_faq_content,
      status: :active
    )

    templates
  end

  private

  def set_version_number
    self.version_number ||= 1
  end

  def major_content_change?
    saved_change_to_content? && content_previously_changed?
  end

  def archive_previous_version
    # 前のバージョンをアーカイブ（実装簡略化）
    self.class.where(
      name: name_was,
      festival: festival,
      template_type: template_type
    ).where.not(id: id).update_all(status: :archived)
  end

  def standard_variables
    {
      "current_date" => Date.current.strftime("%Y年%m月%d日"),
      "current_year" => Date.current.year,
      "festival_name" => festival&.name || "祭り名",
      "festival_date" => festival&.start_date&.strftime("%Y年%m月%d日") || "開催日",
      "application_deadline" => festival&.vendor_application_deadline&.strftime("%Y年%m月%d日") || "申請締切日"
    }
  end

  def calculate_approval_rate
    total = vendor_applications_using_template.where(status: [ :approved, :rejected ]).count
    return 0 if total.zero?

    approved = vendor_applications_using_template.approved.count
    (approved.to_f / total * 100).round(2)
  end

  def calculate_popular_sections
    # テンプレートセクションの使用頻度分析（簡略化）
    template_sections.joins(:template_fields)
                    .group("template_sections.name")
                    .count
  end

  def self.default_application_form_content
    <<~CONTENT
      # 出店申請書

      ## 基本情報
      - 事業者名: {{business_name}}
      - 事業形態: {{business_type}}
      - 代表者名: {{representative_name}}
      - 連絡先: {{contact_info}}

      ## 出店内容
      - 商品・サービス: {{products_services}}
      - 予想売上: {{expected_revenue}}
      - 必要設備: {{required_facilities}}

      ## その他
      - 特記事項: {{special_notes}}

      申請日: {{current_date}}
    CONTENT
  end

  def self.default_guidelines_content
    <<~CONTENT
      # 出店ガイドライン

      ## 申請について
      1. 申請期限: {{application_deadline}}
      2. 必要書類:
         - 営業許可証（該当する場合）
         - 事業計画書
         - 保険証明書

      ## 出店規則
      1. 出店時間: 祭り開催時間に準ずる
      2. 設営・撤去: 指定された時間内に完了すること
      3. 清掃: 出店エリアの清掃は出店者の責任

      ## 禁止事項
      - 指定エリア外での営業
      - 許可されていない商品の販売
      - 騒音や迷惑行為

      ## 問い合わせ先
      祭り実行委員会
      Email: info@festival.example.com
    CONTENT
  end

  def self.default_faq_content
    <<~CONTENT
      # よくある質問

      ## Q: 申請に必要な書類は何ですか？
      A: 基本的には申請書、事業計画書、営業許可証（該当する場合）が必要です。

      ## Q: 申請後の流れはどうなりますか？
      A: 申請受付後、実行委員会で審査を行い、結果をお知らせします。

      ## Q: 出店料はいくらですか？
      A: 出店内容や場所により異なります。詳細は実行委員会にお問い合わせください。

      ## Q: 電源や水道は使用できますか？
      A: 限られた設備のみ利用可能です。事前にお申し込みください。

      ## Q: 雨天の場合はどうなりますか？
      A: 基本的に雨天決行ですが、荒天の場合は中止となる可能性があります。
    CONTENT
  end
end
