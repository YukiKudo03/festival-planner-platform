class FileAnalyticsService
  include ActiveModel::Model

  attr_reader :date_range, :festival_filter, :user_filter

  def initialize(options = {})
    @date_range = options[:date_range] || 30.days.ago..Time.current
    @festival_filter = options[:festival_id]
    @user_filter = options[:user_id]
  end

  # 包括的なファイル分析レポートを生成
  def generate_comprehensive_report
    {
      overview: generate_overview_statistics,
      storage_analysis: generate_storage_analysis,
      usage_patterns: generate_usage_patterns,
      security_analysis: generate_security_analysis,
      performance_metrics: generate_performance_metrics,
      user_activity: generate_user_activity_analysis,
      file_lifecycle: generate_file_lifecycle_analysis,
      trends: generate_trend_analysis,
      recommendations: generate_recommendations
    }
  end

  # ストレージ使用量分析
  def generate_storage_analysis
    file_metadata = base_file_metadata_query
    
    {
      total_files: file_metadata.count,
      total_size: file_metadata.sum(:file_size),
      total_size_formatted: format_bytes(file_metadata.sum(:file_size)),
      average_file_size: file_metadata.average(:file_size)&.round(2) || 0,
      median_file_size: calculate_median_file_size(file_metadata),
      largest_file: find_largest_file(file_metadata),
      smallest_file: find_smallest_file(file_metadata),
      size_distribution: calculate_size_distribution(file_metadata),
      content_type_distribution: calculate_content_type_distribution(file_metadata),
      growth_rate: calculate_storage_growth_rate,
      compression_potential: calculate_compression_potential(file_metadata)
    }
  end

  # 使用パターン分析
  def generate_usage_patterns
    access_logs = base_access_logs_query
    
    {
      total_accesses: access_logs.count,
      unique_users: access_logs.distinct.count(:user_id),
      unique_files: access_logs.distinct.count(:attachment_id),
      access_by_action: access_logs.group(:action).count,
      hourly_distribution: calculate_hourly_distribution(access_logs),
      daily_distribution: calculate_daily_distribution(access_logs),
      weekly_distribution: calculate_weekly_distribution(access_logs),
      monthly_trends: calculate_monthly_trends(access_logs),
      most_accessed_files: find_most_accessed_files(access_logs),
      least_accessed_files: find_least_accessed_files,
      access_patterns_by_user_type: analyze_access_patterns_by_user_type(access_logs)
    }
  end

  # セキュリティ分析
  def generate_security_analysis
    file_metadata = base_file_metadata_query
    
    {
      virus_scan_statistics: calculate_virus_scan_statistics(file_metadata),
      infected_files: find_infected_files(file_metadata),
      quarantined_files: find_quarantined_files(file_metadata),
      suspicious_activities: detect_suspicious_activities,
      file_type_security: analyze_file_type_security(file_metadata),
      upload_source_analysis: analyze_upload_sources,
      security_incidents: calculate_security_incidents,
      compliance_status: calculate_compliance_status(file_metadata)
    }
  end

  # パフォーマンス指標
  def generate_performance_metrics
    file_metadata = base_file_metadata_query
    
    {
      processing_performance: calculate_processing_performance(file_metadata),
      upload_success_rate: calculate_upload_success_rate(file_metadata),
      average_processing_time: calculate_average_processing_time(file_metadata),
      processing_bottlenecks: identify_processing_bottlenecks(file_metadata),
      storage_efficiency: calculate_storage_efficiency(file_metadata),
      bandwidth_utilization: calculate_bandwidth_utilization,
      error_rates: calculate_error_rates(file_metadata),
      optimization_opportunities: identify_optimization_opportunities(file_metadata)
    }
  end

  # ユーザー活動分析
  def generate_user_activity_analysis
    access_logs = base_access_logs_query
    
    {
      top_uploaders: find_top_uploaders,
      top_downloaders: find_top_downloaders(access_logs),
      user_engagement: calculate_user_engagement(access_logs),
      user_behavior_patterns: analyze_user_behavior_patterns(access_logs),
      collaboration_patterns: analyze_collaboration_patterns(access_logs),
      user_storage_usage: calculate_user_storage_usage,
      access_frequency: calculate_access_frequency(access_logs),
      user_activity_trends: calculate_user_activity_trends(access_logs)
    }
  end

  # ファイルライフサイクル分析
  def generate_file_lifecycle_analysis
    file_metadata = base_file_metadata_query
    
    {
      file_age_distribution: calculate_file_age_distribution(file_metadata),
      access_after_upload: calculate_access_after_upload,
      file_retention_patterns: analyze_file_retention_patterns(file_metadata),
      deletion_patterns: analyze_deletion_patterns,
      archive_candidates: identify_archive_candidates(file_metadata),
      orphaned_files: find_orphaned_files,
      unused_files: find_unused_files(file_metadata),
      file_modification_patterns: analyze_file_modification_patterns(file_metadata)
    }
  end

  # トレンド分析
  def generate_trend_analysis
    {
      upload_trends: calculate_upload_trends,
      download_trends: calculate_download_trends,
      storage_growth_trends: calculate_storage_growth_trends,
      user_growth_trends: calculate_user_growth_trends,
      file_type_trends: calculate_file_type_trends,
      seasonal_patterns: identify_seasonal_patterns,
      usage_forecasting: generate_usage_forecasting,
      capacity_planning: generate_capacity_planning_recommendations
    }
  end

  # 推奨事項の生成
  def generate_recommendations
    recommendations = []
    
    # ストレージ最適化の推奨事項
    recommendations.concat(generate_storage_optimization_recommendations)
    
    # セキュリティ強化の推奨事項
    recommendations.concat(generate_security_recommendations)
    
    # パフォーマンス改善の推奨事項
    recommendations.concat(generate_performance_recommendations)
    
    # ユーザー体験改善の推奨事項
    recommendations.concat(generate_user_experience_recommendations)
    
    # コスト最適化の推奨事項
    recommendations.concat(generate_cost_optimization_recommendations)
    
    recommendations
  end

  # CSVエクスポート用データ
  def export_to_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'ファイル名', 'ファイルサイズ', 'コンテンツタイプ', 'アップロード日時',
        'アップロード者', 'アクセス回数', '最終アクセス日時', 'ウイルススキャン状態',
        '処理状態', '所属フェスティバル'
      ]
      
      base_file_metadata_query.includes(:uploaded_by, :attachment).find_each do |metadata|
        attachment = metadata.attachment
        csv << [
          attachment&.blob&.filename,
          format_bytes(metadata.file_size),
          metadata.content_type,
          metadata.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          metadata.uploaded_by.name,
          calculate_access_count(attachment),
          calculate_last_access(attachment),
          metadata.virus_scan_status_text,
          metadata.processing_status_text,
          get_festival_name(attachment)
        ]
      end
    end
  end

  private

  def base_file_metadata_query
    query = FileMetadata.where(created_at: @date_range)
    query = query.joins(attachment: { record: :festival }).where(festivals: { id: @festival_filter }) if @festival_filter
    query = query.where(uploaded_by: @user_filter) if @user_filter
    query
  end

  def base_access_logs_query
    query = FileAccessLog.where(created_at: @date_range)
    query = query.where(user: @user_filter) if @user_filter
    query
  end

  def calculate_median_file_size(file_metadata)
    sizes = file_metadata.pluck(:file_size).sort
    return 0 if sizes.empty?
    
    middle = sizes.length / 2
    sizes.length.odd? ? sizes[middle] : (sizes[middle - 1] + sizes[middle]) / 2.0
  end

  def find_largest_file(file_metadata)
    largest = file_metadata.order(file_size: :desc).first
    return nil unless largest
    
    {
      filename: largest.attachment&.blob&.filename,
      size: largest.file_size,
      size_formatted: format_bytes(largest.file_size),
      uploaded_by: largest.uploaded_by.name,
      uploaded_at: largest.created_at
    }
  end

  def find_smallest_file(file_metadata)
    smallest = file_metadata.where('file_size > 0').order(:file_size).first
    return nil unless smallest
    
    {
      filename: smallest.attachment&.blob&.filename,
      size: smallest.file_size,
      size_formatted: format_bytes(smallest.file_size),
      uploaded_by: smallest.uploaded_by.name,
      uploaded_at: smallest.created_at
    }
  end

  def calculate_size_distribution(file_metadata)
    {
      very_small: file_metadata.where('file_size < ?', 1.kilobyte).count,
      small: file_metadata.where(file_size: 1.kilobyte..100.kilobytes).count,
      medium: file_metadata.where(file_size: 100.kilobytes..1.megabyte).count,
      large: file_metadata.where(file_size: 1.megabyte..10.megabytes).count,
      very_large: file_metadata.where('file_size > ?', 10.megabytes).count
    }
  end

  def calculate_content_type_distribution(file_metadata)
    file_metadata.group(:content_type).count.map do |content_type, count|
      {
        content_type: content_type,
        count: count,
        percentage: (count.to_f / file_metadata.count * 100).round(2),
        total_size: file_metadata.where(content_type: content_type).sum(:file_size),
        average_size: file_metadata.where(content_type: content_type).average(:file_size)&.round(2) || 0
      }
    end
  end

  def calculate_storage_growth_rate
    current_total = FileMetadata.sum(:file_size)
    previous_total = FileMetadata.where('created_at < ?', @date_range.begin).sum(:file_size)
    
    return 0 if previous_total.zero?
    
    ((current_total - previous_total).to_f / previous_total * 100).round(2)
  end

  def calculate_compression_potential(file_metadata)
    compressible_types = ['image/jpeg', 'image/png', 'application/pdf']
    compressible_files = file_metadata.where(content_type: compressible_types)
    
    total_size = compressible_files.sum(:file_size)
    estimated_savings = total_size * 0.3 # 30%の圧縮率を想定
    
    {
      compressible_files: compressible_files.count,
      total_size: total_size,
      estimated_savings: estimated_savings,
      estimated_savings_formatted: format_bytes(estimated_savings),
      potential_savings_percentage: total_size.zero? ? 0 : (estimated_savings / total_size * 100).round(2)
    }
  end

  def calculate_hourly_distribution(access_logs)
    (0..23).map do |hour|
      count = access_logs.where(
        'EXTRACT(hour FROM created_at) = ?', hour
      ).count
      
      {
        hour: hour,
        count: count,
        percentage: access_logs.count.zero? ? 0 : (count.to_f / access_logs.count * 100).round(2)
      }
    end
  end

  def calculate_daily_distribution(access_logs)
    access_logs.group_by_day(:created_at).count.map do |date, count|
      {
        date: date,
        count: count,
        day_of_week: date.strftime('%A')
      }
    end
  end

  def calculate_weekly_distribution(access_logs)
    access_logs.group_by_week(:created_at).count
  end

  def calculate_monthly_trends(access_logs)
    access_logs.group_by_month(:created_at).count
  end

  def find_most_accessed_files(access_logs, limit = 10)
    access_logs.joins(attachment: :blob)
              .group('active_storage_attachments.id', 'active_storage_blobs.filename')
              .order('COUNT(*) DESC')
              .limit(limit)
              .count
              .map do |(attachment_id, filename), count|
      {
        attachment_id: attachment_id,
        filename: filename,
        access_count: count
      }
    end
  end

  def find_least_accessed_files(limit = 10)
    FileMetadata.joins(:attachment)
               .left_joins('LEFT JOIN file_access_logs ON file_access_logs.attachment_id = active_storage_attachments.id')
               .group('active_storage_attachments.id', 'active_storage_blobs.filename')
               .order('COUNT(file_access_logs.id) ASC')
               .limit(limit)
               .count
               .map do |(attachment_id, filename), count|
      {
        attachment_id: attachment_id,
        filename: filename,
        access_count: count
      }
    end
  end

  def analyze_access_patterns_by_user_type(access_logs)
    access_logs.joins(:user)
              .group('users.role')
              .count
              .map do |role, count|
      {
        user_type: role,
        access_count: count,
        percentage: (count.to_f / access_logs.count * 100).round(2)
      }
    end
  end

  def calculate_virus_scan_statistics(file_metadata)
    {
      total_scanned: file_metadata.where.not(virus_scan_status: 'not_scanned').count,
      clean_files: file_metadata.where(virus_scan_status: 'clean').count,
      infected_files: file_metadata.where(virus_scan_status: 'infected').count,
      scan_errors: file_metadata.where(virus_scan_status: 'error').count,
      scan_success_rate: calculate_scan_success_rate(file_metadata)
    }
  end

  def find_infected_files(file_metadata)
    file_metadata.where(virus_scan_status: 'infected')
                .includes(:uploaded_by, :attachment)
                .map do |metadata|
      {
        filename: metadata.attachment&.blob&.filename,
        threat_name: metadata.virus_scan_result&.dig('threat_name'),
        uploaded_by: metadata.uploaded_by.name,
        detected_at: metadata.virus_scan_completed_at
      }
    end
  end

  def find_quarantined_files(file_metadata)
    file_metadata.where(quarantined: true)
                .includes(:uploaded_by, :attachment)
                .map do |metadata|
      {
        filename: metadata.attachment&.blob&.filename,
        quarantine_reason: metadata.quarantine_reason,
        quarantined_at: metadata.quarantined_at,
        uploaded_by: metadata.uploaded_by.name
      }
    end
  end

  def detect_suspicious_activities
    FileAccessLog.detect_suspicious_activity
  end

  def analyze_file_type_security(file_metadata)
    potentially_dangerous = ['application/x-executable', 'application/x-msdownload', 'application/x-msdos-program']
    
    {
      dangerous_files: file_metadata.where(content_type: potentially_dangerous).count,
      unknown_types: file_metadata.where(content_type: 'application/octet-stream').count,
      script_files: file_metadata.where('content_type LIKE ?', '%script%').count
    }
  end

  def analyze_upload_sources
    FileMetadata.joins(:uploaded_by)
               .group('users.role')
               .count
               .map do |role, count|
      {
        user_type: role,
        upload_count: count,
        percentage: (count.to_f / FileMetadata.count * 100).round(2)
      }
    end
  end

  def calculate_security_incidents
    {
      virus_detections: FileMetadata.where(virus_scan_status: 'infected').count,
      quarantine_actions: FileMetadata.where(quarantined: true).count,
      suspicious_activities: FileAccessLog.detect_suspicious_activity.count,
      failed_uploads: FileMetadata.where(processing_status: 'failed').count
    }
  end

  def calculate_compliance_status(file_metadata)
    {
      files_scanned: file_metadata.where.not(virus_scan_status: 'not_scanned').count,
      files_not_scanned: file_metadata.where(virus_scan_status: 'not_scanned').count,
      compliance_rate: calculate_compliance_rate(file_metadata)
    }
  end

  def calculate_compliance_rate(file_metadata)
    total = file_metadata.count
    return 0 if total.zero?
    
    compliant = file_metadata.where(virus_scan_status: 'clean').count
    (compliant.to_f / total * 100).round(2)
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

  def generate_storage_optimization_recommendations
    recommendations = []
    
    # 大きなファイルの圧縮推奨
    large_files = FileMetadata.where('file_size > ?', 10.megabytes).count
    if large_files > 10
      recommendations << {
        type: 'storage_optimization',
        priority: 'medium',
        title: '大きなファイルの圧縮',
        description: "#{large_files}個の大きなファイルが見つかりました。圧縮により容量を削減できます。",
        impact: 'ストレージ容量の削減',
        action: 'ファイル圧縮機能の実装'
      }
    end
    
    recommendations
  end

  def generate_security_recommendations
    recommendations = []
    
    # ウイルススキャンされていないファイルの推奨
    unscanned_files = FileMetadata.where(virus_scan_status: 'not_scanned').count
    if unscanned_files > 0
      recommendations << {
        type: 'security',
        priority: 'high',
        title: 'ウイルススキャンの実行',
        description: "#{unscanned_files}個のファイルがスキャンされていません。",
        impact: 'セキュリティリスクの軽減',
        action: '未スキャンファイルの一括スキャン'
      }
    end
    
    recommendations
  end

  def generate_performance_recommendations
    # パフォーマンス改善の推奨事項を生成
    []
  end

  def generate_user_experience_recommendations
    # ユーザー体験改善の推奨事項を生成
    []
  end

  def generate_cost_optimization_recommendations
    # コスト最適化の推奨事項を生成
    []
  end

  # その他のヘルパーメソッド
  def calculate_access_count(attachment)
    return 0 unless attachment
    FileAccessLog.where(attachment: attachment).count
  end

  def calculate_last_access(attachment)
    return nil unless attachment
    FileAccessLog.where(attachment: attachment).maximum(:created_at)
  end

  def get_festival_name(attachment)
    return nil unless attachment&.record.respond_to?(:festival)
    attachment.record.festival&.name
  end
end