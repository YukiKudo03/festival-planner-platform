class FileUploadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_uploadable, only: [ :create, :destroy ]
  before_action :set_attachment, only: [ :show, :destroy ]
  before_action :authorize_upload!, only: [ :create ]
  before_action :authorize_access!, only: [ :show, :destroy ]

  # POST /file_uploads
  def create
    @file_service = FileUploadService.new(@uploadable, current_user)

    begin
      result = @file_service.upload_files(file_params)

      if result[:success]
        render json: {
          success: true,
          files: result[:files].map { |file| serialize_attachment(file) },
          message: "#{result[:files].count}ファイルがアップロードされました"
        }, status: :created
      else
        render json: {
          success: false,
          errors: result[:errors],
          message: "ファイルのアップロードに失敗しました"
        }, status: :unprocessable_entity
      end
    rescue => error
      Rails.logger.error "File upload error: #{error.message}"
      render json: {
        success: false,
        message: "システムエラーが発生しました"
      }, status: :internal_server_error
    end
  end

  # GET /file_uploads/:id
  def show
    if @attachment.blob.present?
      # アクセスログを記録
      FileAccessLog.create!(
        user: current_user,
        attachment_id: @attachment.id,
        action: "download",
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )

      redirect_to rails_blob_path(@attachment, disposition: params[:disposition] || "inline")
    else
      render json: { error: "ファイルが見つかりません" }, status: :not_found
    end
  end

  # DELETE /file_uploads/:id
  def destroy
    attachment_name = @attachment.blob.filename.to_s

    if @attachment.purge
      render json: {
        success: true,
        message: "#{attachment_name}が削除されました"
      }
    else
      render json: {
        success: false,
        message: "ファイルの削除に失敗しました"
      }, status: :unprocessable_entity
    end
  end

  # GET /file_uploads/preview/:id
  def preview
    @attachment = ActiveStorage::Attachment.find(params[:id])
    authorize_access!

    if @attachment.blob.content_type.start_with?("image/")
      redirect_to rails_representation_path(@attachment.variant(resize_to_limit: [ 800, 600 ]))
    elsif @attachment.blob.content_type == "application/pdf"
      redirect_to rails_blob_path(@attachment, disposition: "inline")
    else
      render json: { error: "プレビューできないファイル形式です" }, status: :unprocessable_entity
    end
  end

  # GET /file_uploads/thumbnails/:id
  def thumbnail
    @attachment = ActiveStorage::Attachment.find(params[:id])
    authorize_access!

    if @attachment.blob.content_type.start_with?("image/")
      redirect_to rails_representation_path(@attachment.variant(resize_to_limit: [ 150, 150 ]))
    else
      # デフォルトファイルアイコン
      send_file Rails.root.join("app/assets/images/file-icon.png"),
                type: "image/png",
                disposition: "inline"
    end
  end

  # GET /file_uploads/list
  def list
    @files = current_user.accessible_files
                        .includes(blob: :attachments)
                        .where(record_type: params[:record_type])
                        .where(record_id: params[:record_id]) if params[:record_id]

    @files = @files.where("active_storage_blobs.filename ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @files = @files.page(params[:page]).per(20)

    render json: {
      files: @files.map { |file| serialize_attachment(file) },
      pagination: {
        current_page: @files.current_page,
        total_pages: @files.total_pages,
        total_count: @files.total_count
      }
    }
  end

  # GET /file_uploads/storage_stats
  def storage_stats
    authorize_admin!

    stats = FileStorageService.new.calculate_storage_stats

    render json: {
      total_files: stats[:total_files],
      total_size: stats[:total_size],
      total_size_formatted: stats[:total_size_formatted],
      files_by_type: stats[:files_by_type],
      largest_files: stats[:largest_files],
      recent_uploads: stats[:recent_uploads],
      storage_usage_by_user: stats[:storage_usage_by_user]
    }
  end

  # POST /file_uploads/bulk_delete
  def bulk_delete
    attachment_ids = params[:attachment_ids] || []

    if attachment_ids.empty?
      return render json: { error: "ファイルが選択されていません" }, status: :bad_request
    end

    deleted_count = 0
    errors = []

    attachment_ids.each do |id|
      attachment = ActiveStorage::Attachment.find_by(id: id)
      next unless attachment

      # アクセス権限をチェック
      begin
        @attachment = attachment
        authorize_access!
        attachment.purge
        deleted_count += 1
      rescue => error
        errors << "ID #{id}: #{error.message}"
      end
    end

    render json: {
      success: deleted_count > 0,
      deleted_count: deleted_count,
      errors: errors,
      message: "#{deleted_count}ファイルが削除されました"
    }
  end

  # POST /file_uploads/scan_virus
  def scan_virus
    attachment_ids = params[:attachment_ids] || []

    if attachment_ids.empty?
      return render json: { error: "ファイルが選択されていません" }, status: :bad_request
    end

    # バックグラウンドでウイルススキャンを実行
    VirusScanJob.perform_later(attachment_ids, current_user.id)

    render json: {
      success: true,
      message: "ウイルススキャンを開始しました。結果は通知でお知らせします。"
    }
  end

  private

  def set_uploadable
    if params[:record_type] && params[:record_id]
      @uploadable = params[:record_type].constantize.find(params[:record_id])
    else
      render json: { error: "無効なアップロード対象です" }, status: :bad_request
    end
  end

  def set_attachment
    @attachment = ActiveStorage::Attachment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "ファイルが見つかりません" }, status: :not_found
  end

  def authorize_upload!
    unless can_upload_to?(@uploadable)
      render json: { error: "アップロード権限がありません" }, status: :forbidden
    end
  end

  def authorize_access!
    unless can_access_file?(@attachment)
      render json: { error: "ファイルへのアクセス権限がありません" }, status: :forbidden
    end
  end

  def authorize_admin!
    unless current_user.admin? || current_user.system_admin?
      render json: { error: "管理者権限が必要です" }, status: :forbidden
    end
  end

  def can_upload_to?(record)
    case record
    when Festival
      record.can_be_modified_by?(current_user)
    when Task
      record.can_be_modified_by?(current_user)
    when VendorApplication
      record.user == current_user || current_user.admin? || current_user.committee_member?
    when User
      record == current_user || current_user.admin?
    else
      false
    end
  end

  def can_access_file?(attachment)
    record = attachment.record

    case record
    when Festival
      record.accessible_by?(current_user)
    when Task
      record.can_be_viewed_by?(current_user)
    when VendorApplication
      record.user == current_user || current_user.admin? || current_user.committee_member?
    when User
      record == current_user || current_user.admin?
    else
      false
    end
  end

  def file_params
    params.permit(files: [])
  end

  def serialize_attachment(attachment)
    {
      id: attachment.id,
      filename: attachment.blob.filename.to_s,
      content_type: attachment.blob.content_type,
      size: attachment.blob.byte_size,
      size_formatted: number_to_human_size(attachment.blob.byte_size),
      created_at: attachment.created_at.iso8601,
      url: rails_blob_path(attachment),
      preview_url: attachment.blob.content_type.start_with?("image/") ?
                    file_upload_preview_path(attachment) : nil,
      thumbnail_url: file_upload_thumbnail_path(attachment),
      download_url: file_upload_path(attachment, disposition: "attachment"),
      record_type: attachment.record_type,
      record_id: attachment.record_id
    }
  end

  def number_to_human_size(size)
    return "0 B" if size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end
end
