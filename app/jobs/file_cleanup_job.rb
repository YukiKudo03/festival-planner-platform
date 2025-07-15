class FileCleanupJob < ApplicationJob
  queue_as :file_maintenance
  
  # リトライ設定
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  # 実行時間制限
  timeout 30.minutes

  def perform(cleanup_type = 'daily', options = {})
    Rails.logger.info "Starting file cleanup job: #{cleanup_type}"
    
    start_time = Time.current
    
    begin
      service = FileCleanupService.new
      
      case cleanup_type
      when 'daily'
        cleanup_stats = service.perform_full_cleanup(daily_options.merge(options))
      when 'weekly'
        cleanup_stats = service.perform_full_cleanup(weekly_options.merge(options))
      when 'monthly'
        cleanup_stats = service.perform_full_cleanup(monthly_options.merge(options))
      else
        cleanup_stats = service.perform_full_cleanup(options)
      end
      
      end_time = Time.current
      execution_time = end_time - start_time
      
      # 実行結果をログに記録
      log_cleanup_results(cleanup_type, cleanup_stats, execution_time)
      
      # 通知を送信
      send_cleanup_notification(cleanup_type, cleanup_stats, execution_time)
      
      # 統計情報をキャッシュに保存
      cache_cleanup_statistics(cleanup_stats)
      
    rescue => error
      Rails.logger.error "File cleanup job failed: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      
      # エラー通知を送信
      send_error_notification(cleanup_type, error)
      
      # エラーを再発生させてジョブを失敗状態にする
      raise error
    end
  end

  private

  def daily_options
    {
      archive_threshold: 6.months.ago,
      log_retention_days: 90,
      cleanup_temp_files: true,
      cleanup_failed_uploads: true,
      cleanup_orphaned_metadata: true,
      cleanup_old_logs: true
    }
  end

  def weekly_options
    {
      archive_threshold: 1.year.ago,
      log_retention_days: 180,
      cleanup_temp_files: true,
      cleanup_failed_uploads: true,
      cleanup_orphaned_metadata: true,
      cleanup_old_logs: true,
      deduplicate_files: true,
      cleanup_virus_scan_results: true
    }
  end

  def monthly_options
    {
      archive_threshold: 2.years.ago,
      log_retention_days: 365,
      cleanup_temp_files: true,
      cleanup_failed_uploads: true,
      cleanup_orphaned_metadata: true,
      cleanup_old_logs: true,
      deduplicate_files: true,
      cleanup_virus_scan_results: true,
      optimize_storage: true,
      compress_old_files: true
    }
  end

  def log_cleanup_results(cleanup_type, cleanup_stats, execution_time)
    Rails.logger.info "File cleanup job completed: #{cleanup_type}"
    Rails.logger.info "Execution time: #{execution_time.round(2)} seconds"
    Rails.logger.info "Files cleaned: #{cleanup_stats[:files_cleaned]}"
    Rails.logger.info "Bytes freed: #{cleanup_stats[:bytes_freed]}"
    Rails.logger.info "Archived files: #{cleanup_stats[:archived_files]}"
    Rails.logger.info "Errors: #{cleanup_stats[:errors].count}"
    
    if cleanup_stats[:errors].any?
      Rails.logger.warn "Cleanup errors:"
      cleanup_stats[:errors].each do |error|
        Rails.logger.warn "  - #{error}"
      end
    end
  end

  def send_cleanup_notification(cleanup_type, cleanup_stats, execution_time)
    # 管理者に通知を送信
    if should_send_notification?(cleanup_type, cleanup_stats)
      admin_users = User.where(admin: true).or(User.where(system_admin: true))
      
      admin_users.each do |admin|
        CleanupNotificationMailer.cleanup_completed(
          admin,
          cleanup_type,
          cleanup_stats,
          execution_time
        ).deliver_later
      end
    end
  end

  def send_error_notification(cleanup_type, error)
    # エラー通知を送信
    admin_users = User.where(admin: true).or(User.where(system_admin: true))
    
    admin_users.each do |admin|
      CleanupNotificationMailer.cleanup_failed(
        admin,
        cleanup_type,
        error.message,
        error.backtrace
      ).deliver_later
    end
  end

  def cache_cleanup_statistics(cleanup_stats)
    # キャッシュに統計情報を保存
    Rails.cache.write(
      'last_cleanup_stats',
      {
        timestamp: Time.current,
        stats: cleanup_stats
      },
      expires_in: 1.week
    )
  end

  def should_send_notification?(cleanup_type, cleanup_stats)
    case cleanup_type
    when 'daily'
      # 日次クリーンアップは大量の削除またはエラーがある場合のみ通知
      cleanup_stats[:files_cleaned] > 100 || 
      cleanup_stats[:bytes_freed] > 1.gigabyte ||
      cleanup_stats[:errors].count > 10
    when 'weekly'
      # 週次クリーンアップは常に通知
      true
    when 'monthly'
      # 月次クリーンアップは常に通知
      true
    else
      # その他の場合は通知
      true
    end
  end

  # 定期実行のスケジュール設定用メソッド
  def self.schedule_daily_cleanup
    perform_later('daily')
  end

  def self.schedule_weekly_cleanup
    perform_later('weekly')
  end

  def self.schedule_monthly_cleanup
    perform_later('monthly')
  end

  # 緊急クリーンアップ
  def self.perform_emergency_cleanup
    perform_later('emergency', {
      dry_run: false,
      archive_threshold: 1.month.ago,
      log_retention_days: 30,
      cleanup_temp_files: true,
      cleanup_failed_uploads: true,
      cleanup_orphaned_metadata: true,
      cleanup_old_logs: true,
      deduplicate_files: true,
      optimize_storage: true
    })
  end
end