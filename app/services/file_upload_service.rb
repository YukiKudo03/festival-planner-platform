class FileUploadService
  include ActiveModel::Model

  attr_reader :record, :user, :errors

  def initialize(record, user)
    @record = record
    @user = user
    @errors = []
  end

  def upload_files(file_params)
    files = file_params[:files] || []

    if files.empty?
      @errors << "ファイルが選択されていません"
      return { success: false, errors: @errors }
    end

    uploaded_files = []

    ActiveRecord::Base.transaction do
      files.each do |file|
        result = upload_single_file(file)

        if result[:success]
          uploaded_files << result[:attachment]
        else
          @errors.concat(result[:errors])
          raise ActiveRecord::Rollback
        end
      end
    end

    if @errors.empty?
      # アップロード成功のログを記録
      log_upload_activity(uploaded_files)

      { success: true, files: uploaded_files }
    else
      { success: false, errors: @errors }
    end
  end

  def upload_single_file(file)
    # ファイル検証
    validation_result = validate_file(file)
    return validation_result unless validation_result[:success]

    # ウイルススキャン（開発環境では省略）
    unless Rails.env.development?
      scan_result = scan_for_virus(file)
      return scan_result unless scan_result[:success]
    end

    # ファイル名の正規化
    normalized_filename = normalize_filename(file.original_filename)

    # 重複チェック
    if duplicate_exists?(normalized_filename)
      normalized_filename = generate_unique_filename(normalized_filename)
    end

    # ファイルアップロード
    begin
      attachment = attach_file_to_record(file, normalized_filename)

      # メタデータの保存
      save_file_metadata(attachment)

      { success: true, attachment: attachment }
    rescue => error
      Rails.logger.error "File upload failed: #{error.message}"
      { success: false, errors: [ "ファイルのアップロードに失敗しました: #{error.message}" ] }
    end
  end

  private

  def validate_file(file)
    errors = []

    # ファイルサイズチェック
    max_size = get_max_file_size
    if file.size > max_size
      errors << "ファイルサイズが制限を超えています (最大: #{number_to_human_size(max_size)})"
    end

    # ファイル形式チェック
    unless allowed_content_type?(file.content_type)
      errors << "許可されていないファイル形式です: #{file.content_type}"
    end

    # ファイル名チェック
    if dangerous_filename?(file.original_filename)
      errors << "危険な文字が含まれたファイル名です"
    end

    # 空ファイルチェック
    if file.size.zero?
      errors << "空のファイルはアップロードできません"
    end

    if errors.empty?
      { success: true }
    else
      { success: false, errors: errors }
    end
  end

  def scan_for_virus(file)
    # 本番環境でのウイルススキャン実装
    # ClamAVやVirusTotalなどのサービスを使用

    begin
      scanner = VirusScannerService.new
      result = scanner.scan_file(file.tempfile.path)

      if result[:infected]
        Rails.logger.warn "Virus detected in file: #{file.original_filename}"
        return { success: false, errors: [ "ウイルスが検出されました" ] }
      end

      { success: true }
    rescue => error
      Rails.logger.error "Virus scan failed: #{error.message}"
      # スキャン失敗の場合はアップロードを拒否
      { success: false, errors: [ "ウイルススキャンに失敗しました" ] }
    end
  end

  def attach_file_to_record(file, filename)
    # レコードタイプに応じて適切なアタッチメント名を決定
    attachment_name = determine_attachment_name(file.content_type)

    case attachment_name
    when :single
      @record.public_send(get_single_attachment_name).attach(
        io: file.open,
        filename: filename,
        content_type: file.content_type
      )
      @record.public_send(get_single_attachment_name)
    when :multiple
      @record.public_send(get_multiple_attachment_name).attach(
        io: file.open,
        filename: filename,
        content_type: file.content_type
      )
      @record.public_send(get_multiple_attachment_name).last
    else
      raise "Unknown attachment configuration"
    end
  end

  def determine_attachment_name(content_type)
    case @record
    when Festival
      if content_type.start_with?("image/")
        :multiple # gallery_images
      else
        :multiple # documents
      end
    when Task
      :multiple # attachments
    when VendorApplication
      :multiple # documents
    when User
      if content_type.start_with?("image/")
        :single # avatar
      else
        :multiple # documents
      end
    else
      :multiple
    end
  end

  def get_single_attachment_name
    case @record
    when Festival
      :main_image
    when User
      :avatar
    else
      :attachment
    end
  end

  def get_multiple_attachment_name
    case @record
    when Festival
      @last_content_type&.start_with?("image/") ? :gallery_images : :documents
    when Task
      :attachments
    when VendorApplication
      :documents
    when User
      :documents
    else
      :attachments
    end
  end

  def normalize_filename(filename)
    # 危険な文字を除去
    normalized = filename.gsub(/[^a-zA-Z0-9\.\-_\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/, "_")

    # 連続するアンダースコアを1つに
    normalized.gsub!(/_+/, "_")

    # 先頭と末尾のアンダースコアを削除
    normalized.gsub!(/^_|_$/, "")

    # 拡張子の保持
    extension = File.extname(filename)
    base_name = File.basename(normalized, extension)

    # 長すぎるファイル名の短縮
    if base_name.length > 100
      base_name = base_name[0, 100]
    end

    "#{base_name}#{extension}"
  end

  def generate_unique_filename(filename)
    base_name = File.basename(filename, File.extname(filename))
    extension = File.extname(filename)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")

    "#{base_name}_#{timestamp}#{extension}"
  end

  def duplicate_exists?(filename)
    case @record
    when Festival
      @record.documents.any? { |doc| doc.blob.filename == filename } ||
      @record.gallery_images.any? { |img| img.blob.filename == filename }
    when Task
      @record.attachments.any? { |att| att.blob.filename == filename }
    when VendorApplication
      @record.documents.any? { |doc| doc.blob.filename == filename }
    when User
      (@record.documents&.any? { |doc| doc.blob.filename == filename }) ||
      (@record.avatar&.blob&.filename == filename)
    else
      false
    end
  end

  def save_file_metadata(attachment)
    FileMetadata.create!(
      attachment_id: attachment.id,
      uploaded_by: @user,
      original_filename: attachment.blob.filename.to_s,
      file_size: attachment.blob.byte_size,
      content_type: attachment.blob.content_type,
      upload_ip: request_ip,
      upload_user_agent: request_user_agent
    )
  rescue => error
    Rails.logger.warn "Failed to save file metadata: #{error.message}"
    # メタデータ保存失敗はファイルアップロード自体は失敗させない
  end

  def log_upload_activity(attachments)
    attachments.each do |attachment|
      ActivityLog.create!(
        user: @user,
        action: "file_upload",
        target: @record,
        details: {
          filename: attachment.blob.filename.to_s,
          file_size: attachment.blob.byte_size,
          content_type: attachment.blob.content_type
        }
      )
    end
  rescue => error
    Rails.logger.warn "Failed to log upload activity: #{error.message}"
  end

  def get_max_file_size
    case @record
    when Festival
      if @last_content_type&.start_with?("image/")
        5.megabytes # 画像は5MB
      else
        10.megabytes # ドキュメントは10MB
      end
    when Task
      10.megabytes
    when VendorApplication
      20.megabytes # 申請書類は大きめに
    when User
      if @last_content_type&.start_with?("image/")
        2.megabytes # プロフィール画像は2MB
      else
        5.megabytes
      end
    else
      10.megabytes
    end
  end

  def allowed_content_type?(content_type)
    @last_content_type = content_type # 後で使用するため保存

    allowed_types = case @record
    when Festival
      %w[
        image/jpeg image/png image/webp image/gif
        application/pdf text/plain
        application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      ]
    when Task
      %w[
        image/jpeg image/png image/webp image/gif
        application/pdf text/plain
        application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        application/zip application/x-rar-compressed
      ]
    when VendorApplication
      %w[
        application/pdf
        application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document
        image/jpeg image/png image/webp
      ]
    when User
      %w[
        image/jpeg image/png image/webp
        application/pdf text/plain
      ]
    else
      %w[image/jpeg image/png application/pdf text/plain]
    end

    allowed_types.include?(content_type)
  end

  def dangerous_filename?(filename)
    # 危険なパターンをチェック
    dangerous_patterns = [
      /\.\./,           # ディレクトリトラバーサル
      /[<>:"|?*]/,      # Windows予約文字
      /^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/i, # Windows予約名
      /\.(exe|bat|cmd|scr|pif|vbs|js)$/i  # 実行可能ファイル
    ]

    dangerous_patterns.any? { |pattern| filename.match?(pattern) }
  end

  def request_ip
    # リクエストコンテキストが利用可能な場合のみ
    Thread.current[:request]&.remote_ip || "unknown"
  end

  def request_user_agent
    # リクエストコンテキストが利用可能な場合のみ
    Thread.current[:request]&.user_agent || "unknown"
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
