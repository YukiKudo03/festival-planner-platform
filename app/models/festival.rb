class Festival < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :forums, dependent: :destroy
  has_many :chat_rooms, dependent: :destroy

  # Active Storage attachments
  has_one_attached :main_image
  has_many_attached :gallery_images
  has_many_attached :documents

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :location, presence: true
  validates :budget, presence: true, numericality: { greater_than: 0 }

  validate :end_date_after_start_date
  validate :main_image_format, if: -> { main_image.attached? }
  validate :gallery_images_format, if: -> { gallery_images.attached? }
  validate :documents_format, if: -> { documents.attached? }

  enum :status, {
    planning: 0,
    scheduled: 1,
    active: 2,
    completed: 3,
    cancelled: 4
  }

  scope :upcoming, -> { where('start_date > ?', Time.current) }
  scope :active, -> { where(status: :active) }
  scope :current_year, -> { where(start_date: Date.current.beginning_of_year..Date.current.end_of_year) }

  def duration_days
    return 0 unless start_date && end_date
    (end_date.to_date - start_date.to_date).to_i + 1
  end

  def upcoming?
    start_date && start_date > Time.current
  end

  def active?
    return false unless start_date && end_date
    Time.current.between?(start_date, end_date)
  end

  def completed?
    end_date && end_date < Time.current
  end

  def budget_formatted
    "¥#{budget&.to_i&.to_s(:delimited)}"
  end

  # ファイル管理用ヘルパー
  def main_image_url(size: :medium)
    return nil unless main_image.attached?
    
    case size
    when :thumbnail
      main_image.variant(resize_to_limit: [150, 150])
    when :medium
      main_image.variant(resize_to_limit: [400, 300])
    when :large
      main_image.variant(resize_to_limit: [800, 600])
    else
      main_image
    end
  end

  def gallery_thumbnails
    gallery_images.map { |img| img.variant(resize_to_limit: [200, 150]) if img.attached? }.compact
  end

  def total_storage_size
    attachments = [main_image, gallery_images, documents].flatten.compact
    attachments.sum { |attachment| attachment.blob&.byte_size || 0 }
  end

  def storage_size_formatted
    size = total_storage_size
    return "0 B" if size.zero?

    units = ['B', 'KB', 'MB', 'GB']
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, 'must be after start date')
    end
  end

  def main_image_format
    return unless main_image.attached?

    unless main_image.blob.content_type.in?(['image/jpeg', 'image/png', 'image/webp'])
      errors.add(:main_image, 'must be a JPEG, PNG, or WebP image')
    end

    if main_image.blob.byte_size > 5.megabytes
      errors.add(:main_image, 'must be less than 5MB')
    end
  end

  def gallery_images_format
    return unless gallery_images.attached?

    gallery_images.each_with_index do |image, index|
      unless image.blob.content_type.in?(['image/jpeg', 'image/png', 'image/webp'])
        errors.add(:gallery_images, "Image #{index + 1} must be a JPEG, PNG, or WebP")
      end

      if image.blob.byte_size > 5.megabytes
        errors.add(:gallery_images, "Image #{index + 1} must be less than 5MB")
      end
    end

    if gallery_images.count > 10
      errors.add(:gallery_images, 'can have maximum 10 images')
    end
  end

  def documents_format
    return unless documents.attached?

    documents.each_with_index do |doc, index|
      unless doc.blob.content_type.in?(['application/pdf', 'text/plain', 'application/msword', 
                                         'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
        errors.add(:documents, "Document #{index + 1} must be PDF, TXT, DOC, or DOCX")
      end

      if doc.blob.byte_size > 10.megabytes
        errors.add(:documents, "Document #{index + 1} must be less than 10MB")
      end
    end

    if documents.count > 20
      errors.add(:documents, 'can have maximum 20 documents')
    end
  end
end