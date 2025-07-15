FactoryBot.define do
  factory :application_template do
    name { Faker::Lorem.words(number: 3).join(" ") }
    description { Faker::Lorem.paragraph }
    template_type { ApplicationTemplate.template_types.keys.sample }
    content { "# Default Template\n\nThis is a test template content." }
    status { :active }
    version_number { 1 }

    association :created_by, factory: :user
    association :festival, factory: :festival

    trait :draft do
      status { :draft }
    end

    trait :archived do
      status { :archived }
    end

    trait :deprecated do
      status { :deprecated }
    end

    trait :global_template do
      festival { nil }
    end

    trait :application_form do
      template_type { :application_form }
      content { "# 出店申請書\n\n基本情報を入力してください。" }
    end

    trait :business_license do
      template_type { :business_license }
      content { "# 営業許可証\n\n許可情報を記載してください。" }
    end

    trait :vendor_agreement do
      template_type { :vendor_agreement }
      content { "# 出店契約書\n\n契約条件を記載します。" }
    end

    trait :guidelines do
      template_type { :guidelines }
      content { "# 出店ガイドライン\n\n出店に関する規則です。" }
    end

    trait :faq do
      template_type { :faq }
      content { "# よくある質問\n\nQ&A形式でまとめています。" }
    end

    trait :with_sections do
      after(:create) do |template|
        create_list(:template_section, 3, application_template: template)
      end
    end

    trait :with_file_attachments do
      after(:create) do |template|
        template.template_file.attach(
          io: StringIO.new("Template file content"),
          filename: "template.pdf",
          content_type: "application/pdf"
        )

        template.sample_documents.attach(
          io: StringIO.new("Sample document content"),
          filename: "sample.pdf",
          content_type: "application/pdf"
        )
      end
    end

  end

  def self.default_template_content
    <<~CONTENT
      # {{template_type}} Template

      ## Basic Information
      - Festival: {{festival_name}}
      - Date: {{current_date}}
      - Year: {{current_year}}

      ## Content
      {{content_placeholder}}

      ## Footer
      Generated on {{current_date}}
    CONTENT
  end

  def self.application_form_content
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

      申請日: {{current_date}}
    CONTENT
  end

  def self.business_license_content
    <<~CONTENT
      # 営業許可証テンプレート

      ## 許可情報
      - 許可番号: {{license_number}}
      - 許可業種: {{business_category}}
      - 有効期限: {{expiry_date}}

      ## 事業者情報
      - 事業者名: {{business_name}}
      - 所在地: {{business_address}}

      発行日: {{current_date}}
    CONTENT
  end

  def self.vendor_agreement_content
    <<~CONTENT
      # 出店契約書

      ## 契約条件
      - 契約期間: {{contract_period}}
      - 出店料: {{vendor_fee}}
      - 設営時間: {{setup_time}}
      - 撤去時間: {{breakdown_time}}

      ## 規約
      {{contract_terms}}

      契約日: {{current_date}}
    CONTENT
  end

  def self.guidelines_content
    <<~CONTENT
      # 出店ガイドライン

      ## 申請について
      1. 申請期限: {{application_deadline}}
      2. 必要書類一覧

      ## 出店規則
      1. 出店時間の遵守
      2. 清掃責任
      3. 安全管理

      ## 禁止事項
      - 指定エリア外での営業
      - 許可されていない商品の販売

      問い合わせ先: {{contact_email}}
    CONTENT
  end

  def self.faq_content
    <<~CONTENT
      # よくある質問

      ## Q: 申請に必要な書類は？
      A: 申請書、事業計画書、営業許可証が必要です。

      ## Q: 申請後の流れは？
      A: 実行委員会で審査後、結果をお知らせします。

      ## Q: 出店料は？
      A: 出店内容により異なります。詳細はお問い合わせください。

      更新日: {{current_date}}
    CONTENT
  end
end