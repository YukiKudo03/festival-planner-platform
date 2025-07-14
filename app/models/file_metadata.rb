class FileMetadata < ApplicationRecord
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :attachment, class_name: "ActiveStorage::Attachment"

  validates :original_filename, presence: true, length: { maximum: 255 }
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :content_type, presence: true, length: { maximum: 100 }
  validates :upload_ip, presence: true, length: { maximum: 45 }
  validates :upload_user_agent, presence: true, length: { maximum: 500 }

  serialize :image_metadata, Hash
  serialize :processing_metadata, Hash

  scope :recent, -> { order(created_at: :desc) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :images, -> { where("content_type LIKE ?", "image/%") }
  scope :documents, -> { where("content_type LIKE ?", "application/%") }
  scope :large_files, ->(size = 5.megabytes) { where("file_size > ?", size) }

  after_create :extract_metadata_async

  def file_size_formatted
    return "0 B" if file_size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    unit_index = 0
    size = file_size.to_f

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def is_image?
    content_type.start_with?("image/")
  end

  def is_document?
    content_type.start_with?("application/") || content_type == "text/plain"
  end

  def is_video?
    content_type.start_with?("video/")
  end

  def is_audio?
    content_type.start_with?("audio/")
  end

  def image_dimensions
    return nil unless is_image? && image_metadata.present?
    "#{image_metadata['width']}x#{image_metadata['height']}"
  end

  def image_resolution_category
    return nil unless is_image? && image_metadata.present?

    width = image_metadata["width"].to_i
    height = image_metadata["height"].to_i
    pixels = width * height

    case pixels
    when 0...100_000
      "low"
    when 100_000...500_000
      "medium"
    when 500_000...2_000_000
      "high"
    else
      "very_high"
    end
  end

  def image_resolution_category_text
    case image_resolution_category
    when "low" then "低解像度"
    when "medium" then "中解像度"
    when "high" then "高解像度"
    when "very_high" then "超高解像度"
    else "不明"
    end
  end

  def processing_completed?
    processing_metadata.present? && processing_metadata["status"] == "completed"
  end

  def processing_failed?
    processing_metadata.present? && processing_metadata["status"] == "failed"
  end

  def processing_status_text
    return "未処理" unless processing_metadata.present?

    case processing_metadata["status"]
    when "pending" then "処理待ち"
    when "processing" then "処理中"
    when "completed" then "完了"
    when "failed" then "失敗"
    else "不明"
    end
  end

  def virus_scan_status
    processing_metadata.dig("virus_scan", "status") || "not_scanned"
  end

  def virus_scan_clean?
    virus_scan_status == "clean"
  end

  def virus_scan_infected?
    virus_scan_status == "infected"
  end

  def virus_scan_status_text
    case virus_scan_status
    when "not_scanned" then "スキャン未実施"
    when "scanning" then "スキャン中"
    when "clean" then "クリーン"
    when "infected" then "ウイルス検出"
    when "error" then "スキャンエラー"
    else "不明"
    end
  end

  def estimated_compression_ratio
    return nil unless is_image?

    # 画像の種類とサイズから圧縮率を推定
    case content_type
    when "image/png"
      file_size > 1.megabyte ? 0.4 : 0.6  # PNGは圧縮率が高い
    when "image/jpeg"
      file_size > 1.megabyte ? 0.7 : 0.8  # JPEGは既に圧縮済み
    when "image/webp"
      0.9  # WebPは既に最適化済み
    else
      0.5
    end
  end

  def potential_savings
    return 0 unless is_image? && estimated_compression_ratio

    (file_size * (1 - estimated_compression_ratio)).to_i
  end

  def potential_savings_formatted
    format_size(potential_savings)
  end

  def self.extract_bulk_metadata(attachment_ids)
    where(attachment_id: attachment_ids).each do |metadata|
      FileMetadataExtractionJob.perform_later(metadata.id)
    end
  end

  def self.generate_metadata_report
    {
      total_files: count,
      total_size: sum(:file_size),
      total_size_formatted: format_total_size,
      content_type_distribution: group(:content_type).count,
      size_distribution: {
        small: where("file_size < ?", 1.megabyte).count,
        medium: where(file_size: 1.megabyte..5.megabytes).count,
        large: where(file_size: 5.megabytes..20.megabytes).count,
        very_large: where("file_size > ?", 20.megabytes).count
      },
      image_resolution_distribution: images.group(:image_resolution_category).count,
      processing_status_distribution: group("processing_metadata->'status'").count,
      virus_scan_distribution: group("processing_metadata->'virus_scan'->'status'").count,
      upload_trends: upload_trends_last_30_days
    }
  end

  def self.cleanup_orphaned_metadata
    # アタッチメントが削除されたメタデータを削除
    orphaned_metadata = left_joins(:attachment)
                       .where(active_storage_attachments: { id: nil })

    deleted_count = orphaned_metadata.count
    orphaned_metadata.delete_all

    { deleted_count: deleted_count }
  end

  def update_processing_status(status, details = {})
    self.processing_metadata = (processing_metadata || {}).merge({
      "status" => status,
      "updated_at" => Time.current.iso8601
    }.merge(details))
    save!
  end

  def update_virus_scan_result(status, details = {})
    virus_scan_data = {
      "status" => status,
      "scanned_at" => Time.current.iso8601
    }.merge(details)

    self.processing_metadata = (processing_metadata || {}).merge({
      "virus_scan" => virus_scan_data
    })
    save!
  end

  def update_image_metadata(dimensions, details = {})
    return unless is_image?

    self.image_metadata = {
      "width" => dimensions[:width],
      "height" => dimensions[:height],
      "extracted_at" => Time.current.iso8601
    }.merge(details)
    save!
  end

  private

  def extract_metadata_async
    FileMetadataExtractionJob.perform_later(id)
  end

  def self.format_total_size
    total = sum(:file_size)
    return "0 B" if total.zero?

    units = [ "B", "KB", "MB", "GB", "TB" ]
    unit_index = 0
    size = total.to_f

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def format_size(size)
    return "0 B" if size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def self.upload_trends_last_30_days
    where("created_at >= ?", 30.days.ago)
      .group_by_day(:created_at, time_zone: "Asia/Tokyo")
      .count
  end
end
