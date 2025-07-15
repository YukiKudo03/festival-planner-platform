class FileCleanupService
  include ActiveModel::Model

  attr_reader :errors, :cleanup_stats

  def initialize
    @errors = []
    @cleanup_stats = {
      files_cleaned: 0,
      bytes_freed: 0,
      orphaned_metadata_cleaned: 0,
      old_logs_cleaned: 0,
      archived_files: 0,
      errors: []
    }
  end

  # 総合的なファイルクリーンアップを実行
  def perform_full_cleanup(options = {})
    Rails.logger.info "Starting full file cleanup process"
    
    begin
      # 各クリーンアップ処理を実行
      cleanup_orphaned_files(options)
      cleanup_old_temporary_files(options)
      cleanup_failed_uploads(options)
      archive_old_files(options)
      cleanup_orphaned_metadata(options)
      cleanup_old_access_logs(options)
      cleanup_virus_scan_results(options)
      optimize_storage(options)
      
      Rails.logger.info "File cleanup completed successfully"
      Rails.logger.info "Stats: #{@cleanup_stats}"
      
      # 統計情報を返す
      @cleanup_stats
    rescue => error
      Rails.logger.error "File cleanup failed: #{error.message}"
      @errors << error.message
      @cleanup_stats[:errors] << error.message
      @cleanup_stats
    end
  end

  # 孤立したファイルのクリーンアップ
  def cleanup_orphaned_files(options = {})
    Rails.logger.info "Cleaning up orphaned files"
    
    # Active Storageの孤立したブロブを特定
    orphaned_blobs = ActiveStorage::Blob.left_joins(:attachments)
                                       .where(active_storage_attachments: { id: nil })
                                       .where('active_storage_blobs.created_at < ?', 1.week.ago)
    
    unless options[:dry_run]
      orphaned_blobs.find_each do |blob|
        begin
          file_size = blob.byte_size
          blob.purge
          
          @cleanup_stats[:files_cleaned] += 1
          @cleanup_stats[:bytes_freed] += file_size
          
          Rails.logger.debug "Cleaned orphaned file: #{blob.filename} (#{file_size} bytes)"
        rescue => error
          Rails.logger.error "Failed to clean orphaned file #{blob.id}: #{error.message}"
          @cleanup_stats[:errors] << "Failed to clean orphaned file #{blob.id}: #{error.message}"
        end
      end
    else
      Rails.logger.info "DRY RUN: Would clean #{orphaned_blobs.count} orphaned files"
    end
  end

  # 古い一時ファイルのクリーンアップ
  def cleanup_old_temporary_files(options = {})
    Rails.logger.info "Cleaning up old temporary files"
    
    temp_directories = [
      Rails.root.join('tmp', 'uploads'),
      Rails.root.join('tmp', 'processing'),
      Rails.root.join('tmp', 'virus_scan')
    ]
    
    temp_directories.each do |temp_dir|
      next unless Dir.exist?(temp_dir)
      
      Dir.glob(File.join(temp_dir, '*')).each do |file_path|
        next unless File.file?(file_path)
        next unless File.mtime(file_path) < 1.day.ago
        
        begin
          file_size = File.size(file_path)
          
          unless options[:dry_run]
            File.delete(file_path)
            @cleanup_stats[:files_cleaned] += 1
            @cleanup_stats[:bytes_freed] += file_size
          end
          
          Rails.logger.debug "Cleaned temporary file: #{file_path} (#{file_size} bytes)"
        rescue => error
          Rails.logger.error "Failed to clean temporary file #{file_path}: #{error.message}"
          @cleanup_stats[:errors] << "Failed to clean temporary file #{file_path}: #{error.message}"
        end
      end
    end
  end

  # 失敗したアップロードのクリーンアップ
  def cleanup_failed_uploads(options = {})
    Rails.logger.info "Cleaning up failed uploads"
    
    # 処理に失敗したファイルメタデータを特定
    failed_metadata = FileMetadata.where(processing_status: 'failed')
                                 .where('created_at < ?', 1.day.ago)
    
    unless options[:dry_run]
      failed_metadata.find_each do |metadata|
        begin
          if metadata.attachment.present?
            file_size = metadata.attachment.blob.byte_size
            metadata.attachment.purge
            
            @cleanup_stats[:files_cleaned] += 1
            @cleanup_stats[:bytes_freed] += file_size
          end
          
          metadata.destroy
          Rails.logger.debug "Cleaned failed upload metadata: #{metadata.id}"
        rescue => error
          Rails.logger.error "Failed to clean failed upload #{metadata.id}: #{error.message}"
          @cleanup_stats[:errors] << "Failed to clean failed upload #{metadata.id}: #{error.message}"
        end
      end
    else
      Rails.logger.info "DRY RUN: Would clean #{failed_metadata.count} failed uploads"
    end
  end

  # 古いファイルのアーカイブ
  def archive_old_files(options = {})
    Rails.logger.info "Archiving old files"
    
    archive_threshold = options[:archive_threshold] || 1.year.ago
    
    # 古いファイルを特定（アクセスされていないもの）
    old_files = ActiveStorage::Attachment.joins(:blob)
                                        .left_joins("LEFT JOIN file_access_logs ON file_access_logs.attachment_id = active_storage_attachments.id")
                                        .where('active_storage_blobs.created_at < ?', archive_threshold)
                                        .where('file_access_logs.created_at IS NULL OR file_access_logs.created_at < ?', 6.months.ago)
                                        .distinct
    
    unless options[:dry_run]
      old_files.find_each do |attachment|
        begin
          # アーカイブ処理（実際の実装では外部ストレージに移動）
          archive_file(attachment)
          @cleanup_stats[:archived_files] += 1
          
          Rails.logger.debug "Archived old file: #{attachment.blob.filename}"
        rescue => error
          Rails.logger.error "Failed to archive file #{attachment.id}: #{error.message}"
          @cleanup_stats[:errors] << "Failed to archive file #{attachment.id}: #{error.message}"
        end
      end
    else
      Rails.logger.info "DRY RUN: Would archive #{old_files.count} old files"
    end
  end

  # 孤立したメタデータのクリーンアップ
  def cleanup_orphaned_metadata(options = {})
    Rails.logger.info "Cleaning up orphaned metadata"
    
    result = FileMetadata.cleanup_orphaned_metadata
    
    unless options[:dry_run]
      @cleanup_stats[:orphaned_metadata_cleaned] = result[:deleted_count]
      Rails.logger.info "Cleaned #{result[:deleted_count]} orphaned metadata records"
    else
      Rails.logger.info "DRY RUN: Would clean #{result[:deleted_count]} orphaned metadata records"
    end
  end

  # 古いアクセスログのクリーンアップ
  def cleanup_old_access_logs(options = {})
    Rails.logger.info "Cleaning up old access logs"
    
    retention_days = options[:log_retention_days] || 90
    
    unless options[:dry_run]
      deleted_count = FileAccessLog.cleanup_old_logs(retention_days)
      @cleanup_stats[:old_logs_cleaned] = deleted_count
      Rails.logger.info "Cleaned #{deleted_count} old access logs"
    else
      old_logs_count = FileAccessLog.where('created_at < ?', retention_days.days.ago).count
      Rails.logger.info "DRY RUN: Would clean #{old_logs_count} old access logs"
    end
  end

  # ウイルススキャン結果のクリーンアップ
  def cleanup_virus_scan_results(options = {})
    Rails.logger.info "Cleaning up old virus scan results"
    
    # 古いスキャン結果を削除
    old_scan_results = FileMetadata.where.not(virus_scan_completed_at: nil)
                                  .where('virus_scan_completed_at < ?', 30.days.ago)
    
    unless options[:dry_run]
      old_scan_results.find_each do |metadata|
        begin
          # ウイルススキャン結果のみをクリア
          metadata.update!(
            virus_scan_status: 'not_scanned',
            virus_scan_result: nil,
            virus_scan_completed_at: nil
          )
        rescue => error
          Rails.logger.error "Failed to clean virus scan result for #{metadata.id}: #{error.message}"
          @cleanup_stats[:errors] << "Failed to clean virus scan result for #{metadata.id}: #{error.message}"
        end
      end
    else
      Rails.logger.info "DRY RUN: Would clean #{old_scan_results.count} old virus scan results"
    end
  end

  # ストレージの最適化
  def optimize_storage(options = {})
    Rails.logger.info "Optimizing storage"
    
    # 重複ファイルの検出と削除
    unless options[:dry_run]
      deduplicate_files
      compress_old_files
      update_storage_statistics
    end
  end

  # 定期実行用のメソッド
  def self.perform_daily_cleanup
    service = new
    service.perform_full_cleanup(
      archive_threshold: 6.months.ago,
      log_retention_days: 90
    )
  end

  def self.perform_weekly_cleanup
    service = new
    service.perform_full_cleanup(
      archive_threshold: 1.year.ago,
      log_retention_days: 180
    )
  end

  def self.perform_monthly_cleanup
    service = new
    service.perform_full_cleanup(
      archive_threshold: 2.years.ago,
      log_retention_days: 365
    )
  end

  # クリーンアップ統計のレポート生成
  def generate_cleanup_report
    {
      cleanup_date: Time.current,
      total_files_cleaned: @cleanup_stats[:files_cleaned],
      total_bytes_freed: @cleanup_stats[:bytes_freed],
      total_bytes_freed_formatted: format_bytes(@cleanup_stats[:bytes_freed]),
      orphaned_metadata_cleaned: @cleanup_stats[:orphaned_metadata_cleaned],
      old_logs_cleaned: @cleanup_stats[:old_logs_cleaned],
      archived_files: @cleanup_stats[:archived_files],
      errors_count: @cleanup_stats[:errors].count,
      errors: @cleanup_stats[:errors],
      storage_statistics: calculate_storage_statistics
    }
  end

  private

  def archive_file(attachment)
    # 実際の実装では、ファイルを外部アーカイブストレージに移動
    # ここでは簡略化してログに記録
    Rails.logger.info "Archiving file #{attachment.id} to cold storage"
    
    # ファイルにアーカイブマーカーを追加
    if attachment.record.respond_to?(:update_column)
      attachment.record.update_column(:archived_at, Time.current)
    end
  end

  def deduplicate_files
    # ファイルハッシュベースでの重複ファイル検出
    duplicates = ActiveStorage::Blob.group(:checksum)
                                   .having('COUNT(*) > 1')
                                   .count
    
    duplicates.each do |checksum, count|
      blobs = ActiveStorage::Blob.where(checksum: checksum).order(:created_at)
      original_blob = blobs.first
      duplicate_blobs = blobs.drop(1)
      
      duplicate_blobs.each do |duplicate|
        begin
          # 重複ファイルの添付を元のファイルに変更
          duplicate.attachments.each do |attachment|
            attachment.update!(blob: original_blob)
          end
          
          duplicate.purge
          @cleanup_stats[:files_cleaned] += 1
          @cleanup_stats[:bytes_freed] += duplicate.byte_size
          
          Rails.logger.debug "Deduplicated file: #{duplicate.filename}"
        rescue => error
          Rails.logger.error "Failed to deduplicate file #{duplicate.id}: #{error.message}"
          @cleanup_stats[:errors] << "Failed to deduplicate file #{duplicate.id}: #{error.message}"
        end
      end
    end
  end

  def compress_old_files
    # 古いファイルの圧縮（実装は簡略化）
    Rails.logger.info "Compressing old files"
    
    old_images = ActiveStorage::Blob.where(content_type: 'image/jpeg')
                                   .where('created_at < ?', 1.year.ago)
                                   .where('byte_size > ?', 1.megabyte)
    
    old_images.find_each do |blob|
      begin
        # 画像圧縮処理（実際の実装では画像処理ライブラリを使用）
        Rails.logger.debug "Compressing image: #{blob.filename}"
      rescue => error
        Rails.logger.error "Failed to compress image #{blob.id}: #{error.message}"
        @cleanup_stats[:errors] << "Failed to compress image #{blob.id}: #{error.message}"
      end
    end
  end

  def update_storage_statistics
    # ストレージ統計の更新
    Rails.cache.delete('storage_statistics')
    Rails.logger.info "Updated storage statistics"
  end

  def calculate_storage_statistics
    {
      total_files: ActiveStorage::Blob.count,
      total_size: ActiveStorage::Blob.sum(:byte_size),
      total_size_formatted: format_bytes(ActiveStorage::Blob.sum(:byte_size)),
      average_file_size: ActiveStorage::Blob.average(:byte_size)&.round(2) || 0,
      largest_file_size: ActiveStorage::Blob.maximum(:byte_size) || 0,
      files_by_type: ActiveStorage::Blob.group(:content_type).count
    }
  end

  def format_bytes(bytes)
    return "0 B" if bytes.zero?

    units = ['B', 'KB', 'MB', 'GB', 'TB']
    unit_index = 0
    size = bytes.to_f

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end
end