class FileStorageService
  include ActiveModel::Model

  def calculate_storage_stats
    {
      total_files: total_files_count,
      total_size: total_storage_size,
      total_size_formatted: format_size(total_storage_size),
      files_by_type: files_by_content_type,
      largest_files: largest_files(10),
      recent_uploads: recent_uploads(10),
      storage_usage_by_user: storage_usage_by_user,
      orphaned_files: orphaned_files_count,
      duplicate_files: potential_duplicate_files
    }
  end

  def cleanup_orphaned_files
    orphaned_blobs = ActiveStorage::Blob.left_joins(:attachments)
                                        .where(active_storage_attachments: { id: nil })
                                        .where("active_storage_blobs.created_at < ?", 1.week.ago)

    deleted_count = 0
    total_size_freed = 0

    orphaned_blobs.find_each do |blob|
      size = blob.byte_size
      blob.purge
      deleted_count += 1
      total_size_freed += size
    end

    {
      deleted_files: deleted_count,
      size_freed: total_size_freed,
      size_freed_formatted: format_size(total_size_freed)
    }
  end

  def cleanup_old_temporary_files
    # 一時的なアップロードファイルのクリーンアップ
    temp_attachments = ActiveStorage::Attachment.joins(:blob)
                                               .where("active_storage_blobs.metadata LIKE ?", "%temporary%")
                                               .where("active_storage_attachments.created_at < ?", 24.hours.ago)

    deleted_count = 0
    total_size_freed = 0

    temp_attachments.find_each do |attachment|
      size = attachment.blob.byte_size
      attachment.purge
      deleted_count += 1
      total_size_freed += size
    end

    {
      deleted_files: deleted_count,
      size_freed: total_size_freed,
      size_freed_formatted: format_size(total_size_freed)
    }
  end

  def generate_storage_report(date_range = 30.days.ago..Time.current)
    start_date = date_range.begin
    end_date = date_range.end

    {
      period: "#{start_date.strftime('%Y-%m-%d')} - #{end_date.strftime('%Y-%m-%d')}",
      new_files: files_uploaded_in_period(start_date, end_date),
      deleted_files: files_deleted_in_period(start_date, end_date),
      storage_growth: calculate_storage_growth(start_date, end_date),
      top_uploaders: top_uploaders_in_period(start_date, end_date),
      file_type_distribution: file_type_distribution_in_period(start_date, end_date),
      average_file_size: calculate_average_file_size(start_date, end_date)
    }
  end

  def optimize_storage
    results = {}

    # 画像ファイルの最適化
    results[:image_optimization] = optimize_images

    # 重複ファイルの検出
    results[:duplicate_detection] = detect_duplicates

    # 古いファイルのアーカイブ提案
    results[:archive_suggestions] = suggest_archival

    results
  end

  def validate_storage_integrity
    issues = []

    # ブロブが存在しないアタッチメント
    missing_blobs = ActiveStorage::Attachment.left_joins(:blob)
                                            .where(active_storage_blobs: { id: nil })

    if missing_blobs.any?
      issues << {
        type: "missing_blobs",
        count: missing_blobs.count,
        description: "ブロブファイルが見つからないアタッチメント"
      }
    end

    # ファイルが存在しないブロブ
    missing_files = []
    ActiveStorage::Blob.find_each do |blob|
      unless blob.service.exist?(blob.key)
        missing_files << blob
      end
    end

    if missing_files.any?
      issues << {
        type: "missing_files",
        count: missing_files.count,
        description: "ファイルが存在しないブロブ"
      }
    end

    {
      healthy: issues.empty?,
      issues: issues,
      total_attachments: ActiveStorage::Attachment.count,
      total_blobs: ActiveStorage::Blob.count
    }
  end

  private

  def total_files_count
    ActiveStorage::Attachment.count
  end

  def total_storage_size
    ActiveStorage::Blob.sum(:byte_size)
  end

  def files_by_content_type
    ActiveStorage::Blob.group(:content_type).count
  end

  def largest_files(limit = 10)
    ActiveStorage::Attachment.joins(:blob)
                            .order("active_storage_blobs.byte_size DESC")
                            .limit(limit)
                            .includes(:blob)
                            .map do |attachment|
      {
        id: attachment.id,
        filename: attachment.blob.filename.to_s,
        size: attachment.blob.byte_size,
        size_formatted: format_size(attachment.blob.byte_size),
        content_type: attachment.blob.content_type,
        created_at: attachment.created_at,
        record_type: attachment.record_type,
        record_id: attachment.record_id
      }
    end
  end

  def recent_uploads(limit = 10)
    ActiveStorage::Attachment.includes(:blob)
                            .order(created_at: :desc)
                            .limit(limit)
                            .map do |attachment|
      {
        id: attachment.id,
        filename: attachment.blob.filename.to_s,
        size: attachment.blob.byte_size,
        size_formatted: format_size(attachment.blob.byte_size),
        content_type: attachment.blob.content_type,
        created_at: attachment.created_at,
        record_type: attachment.record_type,
        record_id: attachment.record_id
      }
    end
  end

  def storage_usage_by_user
    usage = {}

    # Festivalの所有者別ストレージ使用量
    Festival.includes(main_image_attachment: :blob,
                     gallery_images_attachments: :blob,
                     documents_attachments: :blob).each do |festival|
      user_id = festival.user_id
      usage[user_id] ||= { user_id: user_id, size: 0, files: 0 }

      [ festival.main_image, festival.gallery_images, festival.documents ].flatten.compact.each do |attachment|
        usage[user_id][:size] += attachment.blob.byte_size
        usage[user_id][:files] += 1
      end
    end

    # Userの直接ファイル
    User.includes(avatar_attachment: :blob, documents_attachments: :blob).each do |user|
      usage[user.id] ||= { user_id: user.id, size: 0, files: 0 }

      [ user.avatar, user.documents ].flatten.compact.each do |attachment|
        usage[user.id][:size] += attachment.blob.byte_size
        usage[user.id][:files] += 1
      end
    end

    # ユーザー情報を追加
    User.where(id: usage.keys).each do |user|
      usage[user.id][:name] = user.display_name
      usage[user.id][:email] = user.email
      usage[user.id][:size_formatted] = format_size(usage[user.id][:size])
    end

    usage.values.sort_by { |u| -u[:size] }
  end

  def orphaned_files_count
    ActiveStorage::Blob.left_joins(:attachments)
                      .where(active_storage_attachments: { id: nil })
                      .count
  end

  def potential_duplicate_files
    duplicates = []

    # ファイル名とサイズで重複を検出
    ActiveStorage::Blob.group(:filename, :byte_size)
                      .having("COUNT(*) > 1")
                      .count
                      .each do |(filename, size), count|
      duplicate_blobs = ActiveStorage::Blob.where(filename: filename, byte_size: size)

      duplicates << {
        filename: filename,
        size: size,
        size_formatted: format_size(size),
        count: count,
        total_waste: size * (count - 1),
        total_waste_formatted: format_size(size * (count - 1)),
        blob_ids: duplicate_blobs.pluck(:id)
      }
    end

    duplicates.sort_by { |d| -d[:total_waste] }
  end

  def files_uploaded_in_period(start_date, end_date)
    ActiveStorage::Attachment.where(created_at: start_date..end_date).count
  end

  def files_deleted_in_period(start_date, end_date)
    # 削除ログがあれば、それを参照
    # なければ概算値を計算
    0 # 実装依存
  end

  def calculate_storage_growth(start_date, end_date)
    start_size = ActiveStorage::Blob.where("created_at < ?", start_date).sum(:byte_size)
    end_size = ActiveStorage::Blob.where("created_at < ?", end_date).sum(:byte_size)

    growth = end_size - start_size
    growth_rate = start_size > 0 ? (growth.to_f / start_size * 100).round(2) : 0

    {
      absolute_growth: growth,
      absolute_growth_formatted: format_size(growth),
      growth_rate_percent: growth_rate
    }
  end

  def top_uploaders_in_period(start_date, end_date, limit = 5)
    # VendorApplicationのファイルアップロード
    vendor_uploads = VendorApplication.joins(documents_attachments: :blob)
                                    .where("active_storage_attachments.created_at" => start_date..end_date)
                                    .group(:user_id)
                                    .sum("active_storage_blobs.byte_size")

    # Festivalのファイルアップロード
    festival_uploads = Festival.joins(gallery_images_attachments: :blob, documents_attachments: :blob)
                              .where("active_storage_attachments.created_at" => start_date..end_date)
                              .group(:user_id)
                              .sum("active_storage_blobs.byte_size")

    # 合計を計算
    total_uploads = vendor_uploads.merge(festival_uploads) { |k, v1, v2| v1 + v2 }

    top_users = total_uploads.sort_by { |user_id, size| -size }.first(limit)

    top_users.map do |user_id, size|
      user = User.find(user_id)
      {
        user_id: user_id,
        name: user.display_name,
        email: user.email,
        uploaded_size: size,
        uploaded_size_formatted: format_size(size)
      }
    end
  end

  def file_type_distribution_in_period(start_date, end_date)
    ActiveStorage::Blob.joins(:attachments)
                      .where("active_storage_attachments.created_at" => start_date..end_date)
                      .group(:content_type)
                      .count
  end

  def calculate_average_file_size(start_date, end_date)
    blobs = ActiveStorage::Blob.joins(:attachments)
                              .where("active_storage_attachments.created_at" => start_date..end_date)

    return 0 if blobs.empty?

    average = blobs.average(:byte_size).to_i
    {
      average_size: average,
      average_size_formatted: format_size(average)
    }
  end

  def optimize_images
    # 画像最適化の実装（別途バックグラウンドジョブで実行）
    large_images = ActiveStorage::Blob.joins(:attachments)
                                     .where(content_type: [ "image/jpeg", "image/png" ])
                                     .where("byte_size > ?", 1.megabyte)

    {
      optimizable_images: large_images.count,
      potential_savings: estimate_compression_savings(large_images)
    }
  end

  def detect_duplicates
    # より詳細な重複検出（MD5ハッシュベース等）
    potential_duplicate_files
  end

  def suggest_archival
    # 長期間アクセスされていないファイルのアーカイブ提案
    old_attachments = ActiveStorage::Attachment.joins(:blob)
                                              .where("active_storage_attachments.created_at < ?", 1.year.ago)

    {
      archival_candidates: old_attachments.count,
      potential_savings: old_attachments.joins(:blob).sum("active_storage_blobs.byte_size"),
      potential_savings_formatted: format_size(old_attachments.joins(:blob).sum("active_storage_blobs.byte_size"))
    }
  end

  def estimate_compression_savings(blobs)
    # 圧縮による予想節約サイズ（経験値として30%削減と仮定）
    total_size = blobs.sum(:byte_size)
    estimated_savings = total_size * 0.3

    {
      estimated_savings: estimated_savings.to_i,
      estimated_savings_formatted: format_size(estimated_savings)
    }
  end

  def format_size(size)
    return "0 B" if size.zero?

    units = [ "B", "KB", "MB", "GB", "TB" ]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end
end
