class Api::V1::Integrations::BackupController < Api::V1::BaseController
  before_action :set_backup_integration, except: [ :index, :create, :providers ]

  # GET /api/v1/integrations/backup
  def index
    integrations = current_user.backup_integrations.includes(:festival)
    integrations = integrations.where(festival_id: params[:festival_id]) if params[:festival_id]
    integrations = integrations.where(provider: params[:provider]) if params[:provider]
    integrations = integrations.where(active: true) if params[:active] == "true"

    render json: {
      integrations: integrations.map { |integration| serialize_integration(integration) }
    }
  end

  # GET /api/v1/integrations/backup/:id
  def show
    render json: {
      integration: serialize_integration_detailed(@integration)
    }
  end

  # POST /api/v1/integrations/backup
  def create
    @integration = current_user.backup_integrations.build(integration_params)

    if @integration.save
      # Test the connection
      test_result = test_backup_connection(@integration)

      if test_result[:success]
        @integration.update(status: :connected)

        render json: {
          integration: serialize_integration_detailed(@integration),
          message: "Backup integration created successfully",
          connection_test: test_result
        }, status: :created
      else
        @integration.update(status: :error, last_error: test_result[:message])

        render json: {
          integration: serialize_integration_detailed(@integration),
          message: "Backup integration created but connection failed",
          connection_test: test_result
        }, status: :created
      end
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/integrations/backup/:id
  def update
    if @integration.update(integration_params)
      render json: {
        integration: serialize_integration_detailed(@integration),
        message: "Backup integration updated successfully"
      }
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/integrations/backup/:id
  def destroy
    @integration.destroy
    render json: {
      message: "Backup integration deleted successfully"
    }
  end

  # POST /api/v1/integrations/backup/:id/create_backup
  def create_backup
    unless @integration.backup_enabled?
      return render json: {
        error: "Backup integration is not enabled",
        details: "Please check integration status and credentials"
      }, status: :unprocessable_entity
    end

    backup_type = params[:backup_type] || "full"
    options = {
      include_attachments: params[:include_attachments] == "true",
      include_database: params[:include_database] == "true",
      include_integrations: params[:include_integrations] == "true",
      since: params[:since] ? Time.parse(params[:since]) : nil
    }.compact

    # Perform backup asynchronously for large backups
    if params[:async] == "true"
      BackupCreateJob.perform_later(@integration.id, backup_type, options)

      render json: {
        message: "Backup creation started in background",
        integration: serialize_integration(@integration)
      }
    else
      result = @integration.create_backup!(backup_type, options)

      if result[:success]
        render json: {
          backup: serialize_backup_job(result[:backup_job]),
          message: "Backup created successfully",
          integration: serialize_integration(@integration)
        }
      else
        render json: {
          error: "Backup creation failed",
          details: result[:error]
        }, status: :unprocessable_entity
      end
    end
  end

  # GET /api/v1/integrations/backup/:id/backups
  def list_backups
    options = {
      backup_type: params[:backup_type],
      status: params[:status],
      limit: [ params[:limit]&.to_i || 20, 100 ].min
    }.compact

    backups = @integration.list_backups(options)

    render json: {
      backups: backups,
      integration: serialize_integration(@integration)
    }
  end

  # POST /api/v1/integrations/backup/:id/restore/:backup_job_id
  def restore_backup
    backup_job_id = params[:backup_job_id]

    unless backup_job_id
      return render json: {
        error: "Backup job ID is required"
      }, status: :bad_request
    end

    options = {
      restore_festival: params[:restore_festival] != "false",
      restore_tasks: params[:restore_tasks] != "false",
      restore_users: params[:restore_users] == "true",
      restore_integrations: params[:restore_integrations] == "true"
    }

    # Perform restoration asynchronously
    if params[:async] == "true"
      BackupRestoreJob.perform_later(@integration.id, backup_job_id, options)

      render json: {
        message: "Backup restoration started in background",
        integration: serialize_integration(@integration)
      }
    else
      result = @integration.restore_backup!(backup_job_id, options)

      if result[:success]
        render json: {
          message: "Backup restored successfully",
          integration: serialize_integration(@integration)
        }
      else
        render json: {
          error: "Backup restoration failed",
          details: result[:error]
        }, status: :unprocessable_entity
      end
    end
  end

  # DELETE /api/v1/integrations/backup/:id/cleanup
  def cleanup_old_backups
    retention_days = params[:retention_days]&.to_i || @integration.retention_days || 30

    result = @integration.cleanup_old_backups!(retention_days)

    if result[:success]
      render json: {
        message: "Old backups cleaned up successfully",
        deleted_count: result[:deleted_count],
        total_size_freed: result[:total_size_freed],
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: "Backup cleanup failed",
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/backup/:id/export
  def export_data
    export_type = params[:export_type] || "festival_data"

    unless %w[festival_data tasks_csv user_data analytics_data].include?(export_type)
      return render json: {
        error: "Invalid export type",
        valid_types: %w[festival_data tasks_csv user_data analytics_data]
      }, status: :bad_request
    end

    options = {
      format: params[:format] || "json",
      include_attachments: params[:include_attachments] == "true",
      start_date: params[:start_date],
      end_date: params[:end_date]
    }.compact

    result = @integration.export_data(export_type, options)

    if result[:success]
      render json: {
        export: serialize_data_export(result[:data_export]),
        download_url: result[:download_url],
        message: "Data exported successfully",
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: "Data export failed",
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/backup/:id/storage_usage
  def storage_usage
    result = @integration.storage_usage

    if result[:success]
      render json: {
        storage_usage: result.except(:success),
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: "Failed to retrieve storage usage",
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/backup/:id/analytics
  def analytics
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Time.current

    analytics = @integration.backup_analytics(start_date, end_date)

    render json: {
      analytics: analytics,
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      integration: serialize_integration(@integration)
    }
  end

  # POST /api/v1/integrations/backup/:id/test_connection
  def test_connection
    result = test_backup_connection(@integration)

    if result[:success]
      @integration.update(status: :connected, last_error: nil)
    else
      @integration.update(status: :error, last_error: result[:message])
    end

    render json: {
      connection_test: result,
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/backup/:id/backup_jobs/:job_id
  def backup_job_details
    backup_job = @integration.backup_jobs.find(params[:job_id])

    render json: {
      backup_job: serialize_backup_job_detailed(backup_job),
      integration: serialize_integration(@integration)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Backup job not found" }, status: :not_found
  end

  # DELETE /api/v1/integrations/backup/:id/backup_jobs/:job_id
  def delete_backup_job
    backup_job = @integration.backup_jobs.find(params[:job_id])

    if backup_job.backup_path.present?
      # Delete from storage provider
      delete_result = @integration.backup_service.delete_backup(backup_job.backup_path)

      unless delete_result[:success]
        return render json: {
          error: "Failed to delete backup from storage",
          details: delete_result[:error]
        }, status: :unprocessable_entity
      end
    end

    backup_job.destroy

    render json: {
      message: "Backup job deleted successfully",
      integration: serialize_integration(@integration)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Backup job not found" }, status: :not_found
  end

  # GET /api/v1/integrations/backup/providers
  def providers
    render json: {
      providers: [
        {
          id: "aws_s3",
          name: "Amazon S3",
          description: "Secure, durable, and scalable cloud storage",
          features: [ "versioning", "encryption", "incremental_backup", "lifecycle_management" ],
          pricing_model: "pay_per_use",
          storage_classes: [ "standard", "standard_ia", "glacier", "deep_archive" ],
          setup_requirements: [ "access_key", "secret_key", "bucket_name", "region" ]
        },
        {
          id: "google_drive",
          name: "Google Drive",
          description: "Cloud storage and file synchronization service",
          features: [ "version_history", "sharing", "incremental_backup" ],
          pricing_model: "subscription",
          storage_limit: "15GB free, paid plans available",
          setup_requirements: [ "oauth_token", "folder_id" ]
        },
        {
          id: "dropbox",
          name: "Dropbox",
          description: "Cloud storage service with file synchronization",
          features: [ "version_history", "sharing", "smart_sync" ],
          pricing_model: "freemium",
          storage_limit: "2GB free, paid plans available",
          setup_requirements: [ "access_token" ]
        },
        {
          id: "azure_blob",
          name: "Azure Blob Storage",
          description: "Microsoft cloud object storage solution",
          features: [ "versioning", "encryption", "lifecycle_management", "geo_replication" ],
          pricing_model: "pay_per_use",
          storage_tiers: [ "hot", "cool", "archive" ],
          setup_requirements: [ "account_name", "access_key", "container_name" ]
        },
        {
          id: "local_storage",
          name: "Local Storage",
          description: "Store backups on local or network-attached storage",
          features: [ "fast_access", "no_data_transfer_costs" ],
          pricing_model: "hardware_cost_only",
          considerations: [ "backup_redundancy", "disaster_recovery" ],
          setup_requirements: [ "storage_path", "permissions" ]
        }
      ]
    }
  end

  private

  def set_backup_integration
    @integration = current_user.backup_integrations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Backup integration not found" }, status: :not_found
  end

  def integration_params
    params.require(:backup_integration).permit(
      :name, :provider, :festival_id, :active, :access_key, :secret_key,
      :access_token, :refresh_token, :bucket_name, :folder_id, :storage_path,
      :region, :backup_frequency, :compression_type, :retention_days,
      :max_backup_size, :encrypt_backups
    )
  end

  def serialize_integration(integration)
    {
      id: integration.id,
      name: integration.name,
      provider: integration.provider,
      active: integration.active,
      status: integration.status,
      backup_frequency: integration.backup_frequency,
      compression_type: integration.compression_type,
      retention_days: integration.retention_days,
      supports_versioning: integration.supports_versioning?,
      supports_encryption: integration.supports_encryption?,
      supports_incremental_backup: integration.supports_incremental_backup?,
      last_backup_at: integration.last_backup_at&.iso8601,
      last_backup_status: integration.last_backup_status,
      festival: integration.festival ? {
        id: integration.festival.id,
        name: integration.festival.name
      } : nil,
      created_at: integration.created_at.iso8601
    }
  end

  def serialize_integration_detailed(integration)
    serialize_integration(integration).merge(
      bucket_name: integration.bucket_name,
      folder_id: integration.folder_id,
      storage_path: integration.storage_path,
      region: integration.region,
      max_backup_size: integration.max_backup_size,
      encrypt_backups: integration.encrypt_backups,
      last_restore_at: integration.last_restore_at&.iso8601,
      last_restore_status: integration.last_restore_status,
      last_error: integration.last_error,
      updated_at: integration.updated_at.iso8601
    )
  end

  def serialize_backup_job(backup_job)
    {
      id: backup_job.id,
      backup_type: backup_job.backup_type,
      status: backup_job.status,
      backup_size: backup_job.backup_size,
      compression_type: backup_job.compression_type,
      include_attachments: backup_job.include_attachments,
      include_database: backup_job.include_database,
      started_at: backup_job.started_at&.iso8601,
      completed_at: backup_job.completed_at&.iso8601,
      error_message: backup_job.error_message,
      created_at: backup_job.created_at.iso8601
    }
  end

  def serialize_backup_job_detailed(backup_job)
    serialize_backup_job(backup_job).merge(
      backup_path: backup_job.backup_path,
      backup_url: backup_job.backup_url,
      metadata: backup_job.metadata,
      updated_at: backup_job.updated_at.iso8601
    )
  end

  def serialize_data_export(data_export)
    {
      id: data_export.id,
      export_type: data_export.export_type,
      export_format: data_export.export_format,
      status: data_export.status,
      file_size: data_export.file_size,
      include_attachments: data_export.include_attachments,
      started_at: data_export.started_at&.iso8601,
      completed_at: data_export.completed_at&.iso8601,
      error_message: data_export.error_message,
      created_at: data_export.created_at.iso8601
    }
  end

  def test_backup_connection(integration)
    integration.test_connection
  rescue => error
    { success: false, message: error.message }
  end
end
