class BackupIntegration < ApplicationRecord
  belongs_to :user
  belongs_to :festival, optional: true
  has_many :backup_jobs, dependent: :destroy
  has_many :data_exports, dependent: :destroy

  validates :provider, presence: true, inclusion: { in: %w[aws_s3 google_drive dropbox azure_blob local_storage] }
  validates :name, presence: true
  validates :bucket_name, presence: true, if: -> { aws_s3? || azure_blob? }
  validates :folder_id, presence: true, if: :google_drive?

  encrypts :access_key
  encrypts :secret_key
  encrypts :access_token
  encrypts :refresh_token

  scope :active, -> { where(active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }

  enum status: {
    connected: 0,
    disconnected: 1,
    error: 2,
    syncing: 3
  }

  enum backup_frequency: {
    manual: 0,
    daily: 1,
    weekly: 2,
    monthly: 3
  }

  enum compression_type: {
    none: 0,
    zip: 1,
    gzip: 2,
    tar_gz: 3
  }

  before_create :set_defaults
  after_update :schedule_backup, if: :saved_change_to_backup_frequency?

  def aws_s3?
    provider == "aws_s3"
  end

  def google_drive?
    provider == "google_drive"
  end

  def dropbox?
    provider == "dropbox"
  end

  def azure_blob?
    provider == "azure_blob"
  end

  def local_storage?
    provider == "local_storage"
  end

  def backup_enabled?
    active? && connected? && has_valid_credentials?
  end

  def has_valid_credentials?
    case provider
    when "aws_s3"
      access_key.present? && secret_key.present? && bucket_name.present?
    when "google_drive"
      access_token.present? && folder_id.present?
    when "dropbox"
      access_token.present?
    when "azure_blob"
      access_key.present? && bucket_name.present?
    when "local_storage"
      storage_path.present?
    else
      false
    end
  end

  def supports_versioning?
    %w[aws_s3 azure_blob].include?(provider)
  end

  def supports_encryption?
    %w[aws_s3 azure_blob].include?(provider)
  end

  def supports_incremental_backup?
    %w[aws_s3 google_drive azure_blob].include?(provider)
  end

  def backup_service
    @backup_service ||= case provider
    when "aws_s3"
                         AwsS3BackupService.new(self)
    when "google_drive"
                         GoogleDriveBackupService.new(self)
    when "dropbox"
                         DropboxBackupService.new(self)
    when "azure_blob"
                         AzureBlobBackupService.new(self)
    when "local_storage"
                         LocalStorageBackupService.new(self)
    end
  end

  def create_backup!(backup_type = "full", options = {})
    return { success: false, error: "Backup not enabled" } unless backup_enabled?

    begin
      # Create backup job record
      backup_job = backup_jobs.create!(
        backup_type: backup_type,
        status: "running",
        started_at: Time.current,
        backup_size: 0,
        compression_type: compression_type,
        include_attachments: options[:include_attachments] != false,
        include_database: options[:include_database] != false
      )

      # Prepare backup data
      backup_data = prepare_backup_data(backup_type, options)

      # Compress if needed
      if compression_type != "none"
        backup_data = compress_backup_data(backup_data, compression_type)
      end

      # Upload to storage provider
      result = backup_service.upload_backup(backup_data, backup_job)

      if result[:success]
        backup_job.update!(
          status: "completed",
          completed_at: Time.current,
          backup_size: result[:file_size],
          backup_path: result[:backup_path],
          backup_url: result[:backup_url],
          metadata: result[:metadata] || {}
        )

        # Update last backup time
        update!(last_backup_at: Time.current, last_backup_status: "success")

        {
          success: true,
          backup_job: backup_job,
          backup_path: result[:backup_path],
          backup_size: result[:file_size]
        }
      else
        backup_job.update!(
          status: "failed",
          completed_at: Time.current,
          error_message: result[:error]
        )

        update!(last_backup_status: "failed", last_error: result[:error])

        result
      end
    rescue => error
      Rails.logger.error "Backup creation failed for integration #{id}: #{error.message}"

      backup_job&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message
      )

      update!(last_backup_status: "failed", last_error: error.message)

      { success: false, error: error.message }
    end
  end

  def restore_backup!(backup_job_id, options = {})
    return { success: false, error: "Backup not enabled" } unless backup_enabled?

    begin
      backup_job = backup_jobs.find(backup_job_id)

      unless backup_job.completed?
        return { success: false, error: "Backup job not completed" }
      end

      # Download backup from storage provider
      backup_data = backup_service.download_backup(backup_job.backup_path)

      unless backup_data
        return { success: false, error: "Failed to download backup data" }
      end

      # Decompress if needed
      if backup_job.compression_type != "none"
        backup_data = decompress_backup_data(backup_data, backup_job.compression_type)
      end

      # Restore data
      result = restore_backup_data(backup_data, options)

      if result[:success]
        update!(last_restore_at: Time.current, last_restore_status: "success")
        result
      else
        update!(last_restore_status: "failed", last_error: result[:error])
        result
      end
    rescue => error
      Rails.logger.error "Backup restoration failed for integration #{id}: #{error.message}"
      update!(last_restore_status: "failed", last_error: error.message)
      { success: false, error: error.message }
    end
  end

  def list_backups(options = {})
    backups = backup_jobs.order(created_at: :desc)
    backups = backups.where(backup_type: options[:backup_type]) if options[:backup_type]
    backups = backups.where(status: options[:status]) if options[:status]
    backups = backups.limit(options[:limit]) if options[:limit]

    backups.map do |backup_job|
      {
        id: backup_job.id,
        backup_type: backup_job.backup_type,
        status: backup_job.status,
        backup_size: backup_job.backup_size,
        compression_type: backup_job.compression_type,
        backup_path: backup_job.backup_path,
        backup_url: backup_job.backup_url,
        created_at: backup_job.created_at,
        completed_at: backup_job.completed_at,
        metadata: backup_job.metadata
      }
    end
  end

  def cleanup_old_backups!(retention_days = 30)
    return { success: false, error: "Backup not enabled" } unless backup_enabled?

    begin
      cutoff_date = retention_days.days.ago
      old_backups = backup_jobs.where("created_at < ?", cutoff_date).where(status: "completed")

      deleted_count = 0
      total_size_freed = 0

      old_backups.find_each do |backup_job|
        delete_result = backup_service.delete_backup(backup_job.backup_path)

        if delete_result[:success]
          total_size_freed += backup_job.backup_size || 0
          backup_job.destroy
          deleted_count += 1
        end
      end

      {
        success: true,
        deleted_count: deleted_count,
        total_size_freed: total_size_freed
      }
    rescue => error
      Rails.logger.error "Backup cleanup failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def export_data(export_type, options = {})
    begin
      # Create data export record
      data_export = data_exports.create!(
        export_type: export_type,
        status: "running",
        started_at: Time.current,
        export_format: options[:format] || "json",
        include_attachments: options[:include_attachments] == true
      )

      # Prepare export data based on type
      export_data = prepare_export_data(export_type, options)

      # Format data
      formatted_data = format_export_data(export_data, options[:format] || "json")

      # Save to storage
      result = backup_service.upload_export(formatted_data, data_export)

      if result[:success]
        data_export.update!(
          status: "completed",
          completed_at: Time.current,
          file_size: result[:file_size],
          export_path: result[:export_path],
          download_url: result[:download_url]
        )

        {
          success: true,
          data_export: data_export,
          download_url: result[:download_url]
        }
      else
        data_export.update!(
          status: "failed",
          completed_at: Time.current,
          error_message: result[:error]
        )

        result
      end
    rescue => error
      Rails.logger.error "Data export failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def test_connection
    backup_service.test_connection
  rescue => error
    { success: false, message: error.message }
  end

  def storage_usage
    begin
      result = backup_service.get_storage_usage

      if result[:success]
        {
          success: true,
          total_size: result[:total_size],
          used_size: result[:used_size],
          available_size: result[:available_size],
          backup_count: backup_jobs.completed.count,
          oldest_backup: backup_jobs.completed.order(:created_at).first&.created_at,
          newest_backup: backup_jobs.completed.order(:created_at).last&.created_at
        }
      else
        result
      end
    rescue => error
      { success: false, error: error.message }
    end
  end

  def backup_analytics(start_date = 30.days.ago, end_date = Time.current)
    jobs = backup_jobs.where(created_at: start_date..end_date)

    {
      total_backups: jobs.count,
      successful_backups: jobs.where(status: "completed").count,
      failed_backups: jobs.where(status: "failed").count,
      total_backup_size: jobs.where(status: "completed").sum(:backup_size),
      average_backup_size: jobs.where(status: "completed").average(:backup_size)&.round(2) || 0,
      average_backup_duration: calculate_average_duration(jobs.where(status: "completed")),
      backup_frequency_stats: jobs.group(:backup_type).count,
      success_rate: calculate_success_rate(jobs),
      storage_trend: jobs.group_by_day(:created_at, last: 30).sum(:backup_size)
    }
  end

  private

  def set_defaults
    self.active ||= true
    self.status ||= :connected
    self.backup_frequency ||= :manual
    self.compression_type ||= :zip
    self.retention_days ||= 30
    self.max_backup_size ||= 5.gigabytes
  end

  def schedule_backup
    return unless active? && backup_frequency != "manual"

    BackupSchedulerJob.perform_later(id)
  end

  def prepare_backup_data(backup_type, options)
    backup_data = {
      festival: nil,
      tasks: [],
      users: [],
      notifications: [],
      integrations: [],
      metadata: {
        backup_type: backup_type,
        created_at: Time.current.iso8601,
        festival_id: festival&.id,
        user_id: user_id
      }
    }

    case backup_type
    when "full"
      backup_data[:festival] = festival&.as_json(include: [ :tasks, :users, :notifications ])
      backup_data[:tasks] = festival&.tasks&.as_json(include: [ :assignments, :comments ])
      backup_data[:integrations] = user.integrations_data if options[:include_integrations]
    when "festival_only"
      backup_data[:festival] = festival&.as_json
    when "tasks_only"
      backup_data[:tasks] = festival&.tasks&.as_json(include: [ :assignments, :comments ])
    when "incremental"
      backup_data = prepare_incremental_backup_data(options[:since] || last_backup_at)
    end

    # Include file attachments if requested
    if options[:include_attachments]
      backup_data[:attachments] = collect_attachments
    end

    backup_data
  end

  def prepare_incremental_backup_data(since_date)
    return {} unless since_date

    {
      festival: festival&.updated_at > since_date ? festival.as_json : nil,
      tasks: festival&.tasks&.where("updated_at > ?", since_date)&.as_json(include: [ :assignments, :comments ]),
      notifications: festival&.notifications&.where("created_at > ?", since_date)&.as_json,
      metadata: {
        backup_type: "incremental",
        since_date: since_date.iso8601,
        created_at: Time.current.iso8601
      }
    }.compact
  end

  def prepare_export_data(export_type, options)
    case export_type
    when "festival_data"
      festival&.as_json(include: [ :tasks, :users, :notifications ])
    when "tasks_csv"
      festival&.tasks&.as_json
    when "user_data"
      user.as_json(include: [ :festivals, :tasks ])
    when "analytics_data"
      collect_analytics_data(options)
    else
      {}
    end
  end

  def format_export_data(data, format)
    case format.downcase
    when "json"
      JSON.pretty_generate(data)
    when "csv"
      convert_to_csv(data)
    when "xml"
      convert_to_xml(data)
    when "yaml"
      data.to_yaml
    else
      JSON.pretty_generate(data)
    end
  end

  def convert_to_csv(data)
    return "" unless data.is_a?(Array) && data.any?

    require "csv"

    CSV.generate do |csv|
      # Add headers
      csv << data.first.keys if data.first.is_a?(Hash)

      # Add data rows
      data.each do |row|
        csv << (row.is_a?(Hash) ? row.values : row)
      end
    end
  end

  def convert_to_xml(data)
    data.to_xml(root: "backup_data", skip_instruct: true)
  end

  def compress_backup_data(data, compression_type)
    case compression_type
    when "zip"
      compress_zip(data)
    when "gzip"
      compress_gzip(data)
    when "tar_gz"
      compress_tar_gz(data)
    else
      data
    end
  end

  def decompress_backup_data(data, compression_type)
    case compression_type
    when "zip"
      decompress_zip(data)
    when "gzip"
      decompress_gzip(data)
    when "tar_gz"
      decompress_tar_gz(data)
    else
      data
    end
  end

  def compress_zip(data)
    require "zip"

    Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry("backup_data.json")
      zos.write(JSON.pretty_generate(data))
    end.string
  end

  def compress_gzip(data)
    require "zlib"

    Zlib::Deflate.deflate(JSON.pretty_generate(data))
  end

  def compress_tar_gz(data)
    require "zlib"
    require "rubygems/package"

    tar_data = StringIO.new
    Gem::Package::TarWriter.new(tar_data) do |tar|
      tar.add_file("backup_data.json", 0644) do |file|
        file.write(JSON.pretty_generate(data))
      end
    end

    Zlib::GzipWriter.wrap(StringIO.new) do |gz|
      gz.write(tar_data.string)
    end.string
  end

  def restore_backup_data(backup_data, options)
    # Implementation would depend on specific restoration requirements
    # This is a simplified version

    begin
      if backup_data[:festival] && options[:restore_festival] != false
        # Restore festival data
        festival&.update!(backup_data[:festival].except("id", "created_at", "updated_at"))
      end

      if backup_data[:tasks] && options[:restore_tasks] != false
        # Restore tasks data (careful with IDs and relationships)
        restore_tasks_data(backup_data[:tasks])
      end

      { success: true, message: "Backup restored successfully" }
    rescue => error
      { success: false, error: error.message }
    end
  end

  def restore_tasks_data(tasks_data)
    # Implementation would handle task restoration with proper ID mapping
    # This is a placeholder for the complex logic required
    tasks_data.each do |task_data|
      # Restore or update task with careful handling of relationships
    end
  end

  def collect_attachments
    attachments = []

    # Collect festival attachments if any
    if festival && festival.respond_to?(:attachments)
      attachments.concat(festival.attachments.map(&:attachment))
    end

    # Collect task attachments
    festival&.tasks&.each do |task|
      if task.respond_to?(:attachments)
        attachments.concat(task.attachments.map(&:attachment))
      end
    end

    attachments.compact.uniq
  end

  def collect_analytics_data(options)
    start_date = options[:start_date] || 30.days.ago
    end_date = options[:end_date] || Time.current

    {
      festival_stats: festival&.analytics_summary(start_date, end_date),
      task_completion_stats: festival&.task_completion_analytics(start_date, end_date),
      user_activity_stats: festival&.user_activity_analytics(start_date, end_date),
      integration_usage_stats: collect_integration_usage_stats(start_date, end_date)
    }
  end

  def collect_integration_usage_stats(start_date, end_date)
    stats = {}

    user.calendar_integrations.each do |integration|
      stats["calendar_#{integration.id}"] = integration.usage_analytics(start_date, end_date)
    end

    user.social_media_integrations.each do |integration|
      stats["social_#{integration.id}"] = integration.analytics_summary
    end

    user.payment_integrations.each do |integration|
      stats["payment_#{integration.id}"] = integration.analytics_summary(start_date, end_date)
    end

    stats
  end

  def calculate_average_duration(jobs)
    durations = jobs.map do |job|
      next unless job.started_at && job.completed_at
      (job.completed_at - job.started_at).to_i
    end.compact

    return 0 if durations.empty?
    durations.sum / durations.length
  end

  def calculate_success_rate(jobs)
    return 0 if jobs.count.zero?

    success_count = jobs.where(status: "completed").count
    (success_count.to_f / jobs.count * 100).round(2)
  end
end
