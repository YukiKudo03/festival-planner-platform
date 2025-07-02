class FilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_file, only: [:show, :download, :destroy]
  before_action :check_access_permission, only: [:show, :download, :destroy]

  def index
    @files = current_user_files.includes_blobs
    @files = @files.where("active_storage_blobs.filename ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @files = @files.where("active_storage_blobs.content_type LIKE ?", "#{params[:type]}%") if params[:type].present?
    
    @files = @files.order(created_at: :desc).limit(100)
    
    @total_size = @files.sum(&:byte_size)
    @file_count = @files.count
    @file_types = current_user_files.joins(:blob).group("active_storage_blobs.content_type").count
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: file_info }
    end
  end

  def download
    if @file.attached? && can_access_file?(@file)
      redirect_to @file, allow_other_host: true
    else
      redirect_to files_path, alert: 'ファイルにアクセスできません。'
    end
  end

  def destroy
    if can_modify_file?(@file)
      @file.purge
      redirect_to files_path, notice: 'ファイルを削除しました。'
    else
      redirect_to files_path, alert: 'ファイルを削除する権限がありません。'
    end
  end

  def cleanup
    return unless current_user.admin? || current_user.system_admin?

    # 30日以上古い未使用ファイルを削除
    old_blobs = ActiveStorage::Blob.where('created_at < ?', 30.days.ago)
    unused_blobs = old_blobs.left_joins(:attachments).where(active_storage_attachments: { id: nil })
    
    count = unused_blobs.count
    unused_blobs.each(&:purge)
    
    redirect_to files_path, notice: "#{count}個の未使用ファイルを削除しました。"
  end

  def storage_stats
    return unless current_user.admin? || current_user.system_admin?

    @stats = {
      total_files: ActiveStorage::Blob.count,
      total_size: ActiveStorage::Blob.sum(:byte_size),
      by_content_type: ActiveStorage::Blob.group(:content_type).count,
      by_month: ActiveStorage::Blob.group_by_month(:created_at).count,
      largest_files: ActiveStorage::Blob.order(byte_size: :desc).limit(10),
      recent_files: ActiveStorage::Blob.order(created_at: :desc).limit(10)
    }

    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
  end

  private

  def set_file
    @file = ActiveStorage::Attachment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to files_path, alert: 'ファイルが見つかりません。'
  end

  def current_user_files
    # ユーザーがアクセス可能なファイルを取得
    user_festivals = current_user.admin? ? Festival.all : current_user.festivals
    user_tasks = Task.joins(:festival).where(festivals: { id: user_festivals.ids })
    user_applications = VendorApplication.joins(:festival).where(festivals: { id: user_festivals.ids })

    attachable_ids = []
    attachable_types = []

    # ユーザー自身のファイル
    attachable_ids << current_user.id
    attachable_types << 'User'

    # 関連する祭りのファイル
    if user_festivals.any?
      attachable_ids.concat(user_festivals.ids)
      attachable_types.concat(['Festival'] * user_festivals.count)
    end

    # 関連するタスクのファイル
    if user_tasks.any?
      attachable_ids.concat(user_tasks.ids)
      attachable_types.concat(['Task'] * user_tasks.count)
    end

    # 関連する申請のファイル（管理者のみ）
    if current_user.admin? && user_applications.any?
      attachable_ids.concat(user_applications.ids)
      attachable_types.concat(['VendorApplication'] * user_applications.count)
    end

    ActiveStorage::Attachment.joins(:blob)
                             .where(record_id: attachable_ids, record_type: attachable_types)
  end

  def can_access_file?(file)
    return true if current_user.admin? || current_user.system_admin?

    case file.record_type
    when 'User'
      file.record_id == current_user.id
    when 'Festival'
      current_user.festivals.exists?(id: file.record_id)
    when 'Task'
      current_user.tasks.exists?(id: file.record_id) || 
      current_user.festivals.joins(:tasks).exists?(tasks: { id: file.record_id })
    when 'VendorApplication'
      current_user.admin? || file.record.user_id == current_user.id
    else
      false
    end
  end

  def can_modify_file?(file)
    return true if current_user.admin? || current_user.system_admin?

    case file.record_type
    when 'User'
      file.record_id == current_user.id
    when 'Festival'
      current_user.festivals.exists?(id: file.record_id)
    when 'Task'
      current_user.tasks.exists?(id: file.record_id)
    when 'VendorApplication'
      file.record.user_id == current_user.id
    else
      false
    end
  end

  def check_access_permission
    unless can_access_file?(@file)
      redirect_to files_path, alert: 'このファイルにアクセスする権限がありません。'
    end
  end

  def file_info
    {
      id: @file.id,
      filename: @file.blob.filename,
      content_type: @file.blob.content_type,
      byte_size: @file.blob.byte_size,
      created_at: @file.created_at,
      record_type: @file.record_type,
      record_id: @file.record_id,
      url: @file.attached? ? url_for(@file) : nil
    }
  end
end