class FileMetadataExtractionJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(file_metadata_id)
    metadata = FileMetadata.find(file_metadata_id)
    attachment = metadata.attachment

    return unless attachment&.blob&.present?

    begin
      metadata.update_processing_status("processing")

      # 基本メタデータの抽出
      extract_basic_metadata(metadata, attachment)

      # ファイル形式に応じた詳細メタデータの抽出
      case metadata.content_type
      when /^image\//
        extract_image_metadata(metadata, attachment)
      when /^application\/pdf/
        extract_pdf_metadata(metadata, attachment)
      when /^application\/(msword|vnd\.openxmlformats)/
        extract_document_metadata(metadata, attachment)
      end

      # ウイルススキャン（本番環境のみ）
      if Rails.env.production?
        perform_virus_scan(metadata, attachment)
      else
        metadata.update_virus_scan_result("clean", { environment: "development" })
      end

      metadata.update_processing_status("completed", {
        processed_at: Time.current.iso8601,
        extraction_duration: (Time.current - metadata.created_at).round(2)
      })

    rescue => error
      Rails.logger.error "File metadata extraction failed for #{metadata.id}: #{error.message}"
      metadata.update_processing_status("failed", {
        error_message: error.message,
        error_class: error.class.name,
        failed_at: Time.current.iso8601
      })

      # エラー通知を送信
      notify_extraction_failure(metadata, error)
    end
  end

  private

  def extract_basic_metadata(metadata, attachment)
    blob = attachment.blob

    # ファイルハッシュの計算
    blob.open do |file|
      file_hash = Digest::SHA256.file(file.path).hexdigest

      metadata.processing_metadata = (metadata.processing_metadata || {}).merge({
        "file_hash" => file_hash,
        "checksum" => blob.checksum,
        "key" => blob.key,
        "service_name" => blob.service_name
      })
      metadata.save!
    end
  end

  def extract_image_metadata(metadata, attachment)
    blob = attachment.blob

    begin
      blob.open do |file|
        # ImageProcessingを使用してメタデータを抽出
        image_analyzer = ActiveStorage::Analyzer::ImageAnalyzer.new(blob)
        analysis_metadata = image_analyzer.metadata

        # MiniMagickを使用してより詳細な情報を取得
        require "mini_magick"
        image = MiniMagick::Image.open(file.path)

        extended_metadata = {
          "width" => analysis_metadata[:width] || image.width,
          "height" => analysis_metadata[:height] || image.height,
          "format" => image.type,
          "colorspace" => image.colorspace,
          "resolution" => image.resolution,
          "quality" => extract_jpeg_quality(image),
          "has_transparency" => has_transparency?(image),
          "exif_data" => extract_safe_exif_data(image)
        }

        metadata.update_image_metadata(extended_metadata)

        # 最適化提案を生成
        generate_optimization_suggestions(metadata, extended_metadata)
      end
    rescue => error
      Rails.logger.warn "Image metadata extraction failed: #{error.message}"
      metadata.update_image_metadata({ "error" => error.message })
    end
  end

  def extract_pdf_metadata(metadata, attachment)
    blob = attachment.blob

    begin
      blob.open do |file|
        # PDFメタデータの抽出（pdf-readerやpoppler等を使用）
        # ここでは簡略化
        pdf_metadata = {
          "file_type" => "pdf",
          "estimated_pages" => estimate_pdf_pages(file),
          "text_extractable" => true
        }

        metadata.processing_metadata = (metadata.processing_metadata || {}).merge({
          "pdf_metadata" => pdf_metadata
        })
        metadata.save!
      end
    rescue => error
      Rails.logger.warn "PDF metadata extraction failed: #{error.message}"
    end
  end

  def extract_document_metadata(metadata, attachment)
    blob = attachment.blob

    begin
      blob.open do |file|
        # Officeドキュメントのメタデータ抽出
        doc_metadata = {
          "file_type" => determine_document_type(metadata.content_type),
          "estimated_word_count" => 0, # 実装依存
          "has_macros" => false # セキュリティチェック
        }

        metadata.processing_metadata = (metadata.processing_metadata || {}).merge({
          "document_metadata" => doc_metadata
        })
        metadata.save!
      end
    rescue => error
      Rails.logger.warn "Document metadata extraction failed: #{error.message}"
    end
  end

  def perform_virus_scan(metadata, attachment)
    begin
      # ウイルススキャンサービスの実装
      scanner = VirusScannerService.new

      attachment.blob.open do |file|
        scan_result = scanner.scan_file(file.path)

        metadata.update_virus_scan_result(
          scan_result[:infected] ? "infected" : "clean",
          {
            scanner_version: scan_result[:scanner_version],
            virus_definitions_date: scan_result[:definitions_date],
            scan_duration: scan_result[:duration]
          }
        )

        # ウイルスが検出された場合の処理
        if scan_result[:infected]
          handle_infected_file(metadata, attachment, scan_result)
        end
      end
    rescue => error
      Rails.logger.error "Virus scan failed: #{error.message}"
      metadata.update_virus_scan_result("error", { error_message: error.message })
    end
  end

  def extract_jpeg_quality(image)
    return nil unless image.type.downcase == "jpeg"

    begin
      # JPEG品質の推定（実装依存）
      quality_info = image["%[jpeg:quality]"]
      quality_info.to_i if quality_info.present?
    rescue
      nil
    end
  end

  def has_transparency?(image)
    begin
      alpha_channel = image["%[channels]"].include?("a")
      matte = image["%[matte]"] == "True"
      alpha_channel || matte
    rescue
      false
    end
  end

  def extract_safe_exif_data(image)
    # 個人情報を含まない安全なEXIFデータのみを抽出
    safe_fields = %w[
      exif:DateTime
      exif:Make
      exif:Model
      exif:Software
      exif:ColorSpace
      exif:PixelXDimension
      exif:PixelYDimension
      exif:Orientation
    ]

    exif_data = {}
    safe_fields.each do |field|
      begin
        value = image["%[#{field}]"]
        exif_data[field.gsub("exif:", "")] = value if value.present?
      rescue
        # EXIFデータの取得に失敗した場合は無視
      end
    end

    exif_data
  end

  def generate_optimization_suggestions(metadata, image_metadata)
    suggestions = []

    width = image_metadata["width"].to_i
    height = image_metadata["height"].to_i
    file_size = metadata.file_size

    # サイズ最適化の提案
    if width > 2000 || height > 2000
      suggestions << {
        type: "resize",
        suggestion: "画像サイズが大きすぎます。リサイズを検討してください。",
        recommended_max_size: "2000x2000"
      }
    end

    # 圧縮最適化の提案
    if file_size > 1.megabyte && metadata.content_type == "image/png"
      suggestions << {
        type: "compression",
        suggestion: "PNGファイルが大きいです。JPEG形式への変換を検討してください。",
        potential_savings: "#{(file_size * 0.6).to_i}"
      }
    end

    # WebP変換の提案
    unless metadata.content_type == "image/webp"
      suggestions << {
        type: "format_conversion",
        suggestion: "WebP形式に変換することでファイルサイズを削減できます。",
        potential_savings: "#{(file_size * 0.3).to_i}"
      }
    end

    metadata.processing_metadata = (metadata.processing_metadata || {}).merge({
      "optimization_suggestions" => suggestions
    })
    metadata.save!
  end

  def estimate_pdf_pages(file)
    # PDFページ数の簡易推定
    content = file.read(1.kilobyte)
    content.scan(/\/Count\s+(\d+)/).flatten.first&.to_i || 1
  rescue
    1
  end

  def determine_document_type(content_type)
    case content_type
    when "application/msword"
      "doc"
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "docx"
    when "application/vnd.ms-excel"
      "xls"
    when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      "xlsx"
    when "application/vnd.ms-powerpoint"
      "ppt"
    when "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "pptx"
    else
      "unknown"
    end
  end

  def handle_infected_file(metadata, attachment, scan_result)
    # ウイルス検出時の処理
    Rails.logger.error "Virus detected in file: #{metadata.original_filename}"

    # ファイルを隔離（削除またはアクセス制限）
    begin
      attachment.purge_later
    rescue => error
      Rails.logger.error "Failed to purge infected file: #{error.message}"
    end

    # 管理者に通知
    AdminNotificationMailer.virus_detected(metadata, scan_result).deliver_later

    # ユーザーに通知
    UserNotificationMailer.file_quarantined(metadata.uploaded_by, metadata).deliver_later
  end

  def notify_extraction_failure(metadata, error)
    # メタデータ抽出失敗の通知
    if Rails.env.production?
      AdminNotificationMailer.metadata_extraction_failed(metadata, error).deliver_later
    end
  end
end
