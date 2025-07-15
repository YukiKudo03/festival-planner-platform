class TemplateVersionService
  include ActiveModel::Model

  attr_reader :template, :current_user, :errors

  def initialize(template, current_user)
    @template = template
    @current_user = current_user
    @errors = []
  end

  # 新しいバージョンを作成
  def create_new_version(attributes = {})
    return false unless can_create_version?

    ApplicationRecord.transaction do
      # 現在のバージョンを非推奨にする
      deprecate_current_version if template.active?

      # 新しいバージョンを作成
      new_version = template.dup
      new_version.assign_attributes(attributes)
      new_version.version_number = next_version_number
      new_version.parent_template_id = template.id
      new_version.status = :draft
      new_version.created_by = current_user
      new_version.created_at = Time.current
      new_version.updated_at = Time.current

      if new_version.save
        # テンプレートセクションを複製
        duplicate_sections(new_version)
        
        # バージョン履歴を記録
        create_version_history(new_version, 'version_created')
        
        new_version
      else
        @errors = new_version.errors.full_messages
        raise ActiveRecord::Rollback
      end
    end
  end

  # テンプレートを復元
  def restore_version(version_id)
    return false unless can_restore_version?

    version_to_restore = ApplicationTemplate.find_by(id: version_id, parent_template_id: template.id)
    return false unless version_to_restore

    ApplicationRecord.transaction do
      # 現在のバージョンをバックアップ
      backup_current_version

      # 復元するバージョンの内容を現在のテンプレートに適用
      template.assign_attributes(
        content: version_to_restore.content,
        name: version_to_restore.name,
        description: version_to_restore.description,
        status: :active,
        version_number: next_version_number
      )

      if template.save
        # セクションを復元
        restore_sections(version_to_restore)
        
        # バージョン履歴を記録
        create_version_history(template, 'version_restored', { restored_from: version_id })
        
        template
      else
        @errors = template.errors.full_messages
        raise ActiveRecord::Rollback
      end
    end
  end

  # バージョン比較
  def compare_versions(version1_id, version2_id = nil)
    version1 = find_version(version1_id)
    version2 = version2_id ? find_version(version2_id) : template

    return nil unless version1 && version2

    {
      version1: version_summary(version1),
      version2: version_summary(version2),
      content_diff: generate_content_diff(version1.content, version2.content),
      sections_diff: generate_sections_diff(version1, version2),
      metadata_diff: generate_metadata_diff(version1, version2)
    }
  end

  # バージョン履歴を取得
  def version_history
    ApplicationTemplate.where(parent_template_id: template.id)
                      .or(ApplicationTemplate.where(id: template.id))
                      .order(version_number: :desc)
                      .includes(:created_by)
                      .map do |version|
      {
        id: version.id,
        version_number: version.version_number,
        status: version.status,
        created_by: version.created_by&.name,
        created_at: version.created_at,
        changes_summary: generate_changes_summary(version),
        is_current: version.id == template.id
      }
    end
  end

  # バージョン統計
  def version_statistics
    versions = ApplicationTemplate.where(parent_template_id: template.id)
                                 .or(ApplicationTemplate.where(id: template.id))

    {
      total_versions: versions.count,
      active_versions: versions.where(status: :active).count,
      draft_versions: versions.where(status: :draft).count,
      deprecated_versions: versions.where(status: :deprecated).count,
      latest_version: versions.maximum(:version_number),
      first_created: versions.minimum(:created_at),
      last_updated: versions.maximum(:updated_at),
      contributors: versions.joins(:created_by).distinct.count('users.id')
    }
  end

  # バージョンの削除
  def delete_version(version_id)
    return false unless can_delete_version?

    version_to_delete = find_version(version_id)
    return false unless version_to_delete
    return false if version_to_delete.id == template.id # 現在のバージョンは削除不可

    # 使用中のバージョンは削除不可
    if version_in_use?(version_to_delete)
      @errors << "このバージョンは使用中のため削除できません"
      return false
    end

    ApplicationRecord.transaction do
      # バージョン履歴を記録
      create_version_history(template, 'version_deleted', { deleted_version: version_id })
      
      # バージョンを削除
      version_to_delete.destroy
    end

    true
  end

  # 自動バックアップ
  def create_automatic_backup(reason = 'automatic_backup')
    return false unless should_create_backup?

    backup_template = template.dup
    backup_template.name = "#{template.name} (バックアップ #{Time.current.strftime('%Y%m%d_%H%M%S')})"
    backup_template.status = :archived
    backup_template.version_number = next_version_number
    backup_template.parent_template_id = template.id
    backup_template.created_by = current_user || template.created_by

    if backup_template.save
      duplicate_sections(backup_template)
      create_version_history(backup_template, 'backup_created', { reason: reason })
      backup_template
    else
      false
    end
  end

  # バージョンのマージ
  def merge_versions(source_version_id, target_version_id = nil)
    return false unless can_merge_versions?

    source_version = find_version(source_version_id)
    target_version = target_version_id ? find_version(target_version_id) : template

    return false unless source_version && target_version

    ApplicationRecord.transaction do
      # マージ戦略を適用
      merged_content = merge_content(source_version.content, target_version.content)
      
      # ターゲットバージョンを更新
      target_version.update!(
        content: merged_content,
        version_number: next_version_number
      )

      # マージ履歴を記録
      create_version_history(target_version, 'version_merged', {
        source_version: source_version_id,
        target_version: target_version_id
      })

      target_version
    end
  end

  # バージョンの公開
  def publish_version(version_id)
    return false unless can_publish_version?

    version_to_publish = find_version(version_id)
    return false unless version_to_publish

    ApplicationRecord.transaction do
      # 現在のアクティブバージョンを非推奨にする
      deprecate_current_version if template.active?

      # 指定されたバージョンをアクティブにする
      version_to_publish.update!(status: :active)

      # メインテンプレートを更新
      if version_to_publish.id != template.id
        template.update!(
          content: version_to_publish.content,
          name: version_to_publish.name,
          description: version_to_publish.description,
          status: :active,
          version_number: version_to_publish.version_number
        )
      end

      # 公開履歴を記録
      create_version_history(template, 'version_published', { published_version: version_id })

      template
    end
  end

  private

  def can_create_version?
    return false unless current_user
    return false unless template.can_be_edited_by?(current_user)
    true
  end

  def can_restore_version?
    can_create_version?
  end

  def can_delete_version?
    can_create_version?
  end

  def can_merge_versions?
    can_create_version?
  end

  def can_publish_version?
    can_create_version?
  end

  def should_create_backup?
    return false unless template.persisted?
    return false if template.updated_at < 1.hour.ago # 最近更新されていない場合はバックアップ不要
    true
  end

  def next_version_number
    max_version = ApplicationTemplate.where(parent_template_id: template.id)
                                   .or(ApplicationTemplate.where(id: template.id))
                                   .maximum(:version_number) || 0
    max_version + 1
  end

  def deprecate_current_version
    template.update!(status: :deprecated)
  end

  def backup_current_version
    create_automatic_backup('before_restore')
  end

  def duplicate_sections(new_template)
    template.template_sections.each do |section|
      new_section = section.dup
      new_section.application_template = new_template
      new_section.save!

      section.template_fields.each do |field|
        new_field = field.dup
        new_field.template_section = new_section
        new_field.save!
      end
    end
  end

  def restore_sections(version_to_restore)
    # 現在のセクションを削除
    template.template_sections.destroy_all

    # 復元するバージョンのセクションを複製
    version_to_restore.template_sections.each do |section|
      new_section = section.dup
      new_section.application_template = template
      new_section.save!

      section.template_fields.each do |field|
        new_field = field.dup
        new_field.template_section = new_section
        new_field.save!
      end
    end
  end

  def find_version(version_id)
    ApplicationTemplate.find_by(id: version_id)
  end

  def version_summary(version)
    {
      id: version.id,
      name: version.name,
      version_number: version.version_number,
      status: version.status,
      created_by: version.created_by&.name,
      created_at: version.created_at,
      sections_count: version.template_sections.count,
      content_length: version.content.length
    }
  end

  def generate_content_diff(content1, content2)
    require 'diff/lcs'
    
    lines1 = content1.lines
    lines2 = content2.lines
    
    diffs = Diff::LCS.diff(lines1, lines2)
    
    {
      additions: diffs.select { |change| change.action == '+' }.count,
      deletions: diffs.select { |change| change.action == '-' }.count,
      changes: diffs.count,
      diff_details: diffs.map do |change|
        {
          action: change.action,
          line_number: change.position,
          content: change.element
        }
      end
    }
  end

  def generate_sections_diff(version1, version2)
    sections1 = version1.template_sections.pluck(:name, :section_type)
    sections2 = version2.template_sections.pluck(:name, :section_type)

    {
      added_sections: sections2 - sections1,
      removed_sections: sections1 - sections2,
      common_sections: sections1 & sections2
    }
  end

  def generate_metadata_diff(version1, version2)
    {
      name_changed: version1.name != version2.name,
      description_changed: version1.description != version2.description,
      type_changed: version1.template_type != version2.template_type,
      status_changed: version1.status != version2.status
    }
  end

  def generate_changes_summary(version)
    # 前のバージョンと比較して変更の概要を生成
    previous_version = ApplicationTemplate.where(parent_template_id: template.id)
                                         .where('version_number < ?', version.version_number)
                                         .order(version_number: :desc)
                                         .first

    return "初期バージョン" unless previous_version

    changes = []
    changes << "名前変更" if version.name != previous_version.name
    changes << "説明変更" if version.description != previous_version.description
    changes << "コンテンツ変更" if version.content != previous_version.content
    changes << "ステータス変更" if version.status != previous_version.status

    changes.empty? ? "変更なし" : changes.join(", ")
  end

  def version_in_use?(version)
    # バージョンが使用中かどうかをチェック
    VendorApplication.exists?(application_template: version)
  end

  def create_version_history(template, action, details = {})
    # バージョン履歴テーブルがあれば記録
    # 簡略化のため、ここではログに記録
    Rails.logger.info "Template version history: #{action} for template #{template.id} by user #{current_user&.id}"
  end

  def merge_content(source_content, target_content)
    # 簡単なマージ戦略：ソースの内容をターゲットに追加
    # 実際の実装では、より高度なマージアルゴリズムを使用
    "#{target_content}\n\n--- マージされた内容 ---\n#{source_content}"
  end
end