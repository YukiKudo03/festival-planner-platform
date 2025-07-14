class Festival < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :forums, dependent: :destroy
  has_many :chat_rooms, dependent: :destroy
  has_many :budget_categories, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :revenues, dependent: :destroy
  has_many :budget_approvals, dependent: :destroy
  has_many :venues, dependent: :destroy
  has_many :venue_areas, through: :venues
  has_many :booths, dependent: :destroy
  has_many :layout_elements, through: :venues
  has_many :payments, dependent: :destroy
  has_many :industry_specializations, dependent: :destroy
  has_many :tourism_collaborations, dependent: :destroy

  # LINE連携関連
  has_many :line_integrations, dependent: :destroy
  has_many :line_groups, through: :line_integrations
  has_many :line_messages, through: :line_groups

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

  # Callbacks
  after_create :create_default_budget_categories
  after_create :create_default_venue

  enum :status, {
    planning: 0,
    scheduled: 1,
    active: 2,
    completed: 3,
    cancelled: 4
  }

  scope :upcoming, -> { where("start_date > ?", Time.current) }
  scope :active, -> { where(status: :active) }
  scope :current_year, -> { where(start_date: Date.current.beginning_of_year..Date.current.end_of_year) }
  scope :public_festivals, -> { where(public: true) }

  # Search functionality
  scope :search, ->(query) do
    return all if query.blank?
    where("name ILIKE ? OR location ILIKE ? OR description ILIKE ?",
          "%#{query}%", "%#{query}%", "%#{query}%")
  end

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
      main_image.variant(resize_to_limit: [ 150, 150 ])
    when :medium
      main_image.variant(resize_to_limit: [ 400, 300 ])
    when :large
      main_image.variant(resize_to_limit: [ 800, 600 ])
    else
      main_image
    end
  end

  def gallery_thumbnails
    gallery_images.map { |img| img.variant(resize_to_limit: [ 200, 150 ]) if img.attached? }.compact
  end

  def total_storage_size
    attachments = [ main_image, gallery_images, documents ].flatten.compact
    attachments.sum { |attachment| attachment.blob&.byte_size || 0 }
  end

  def storage_size_formatted
    size = total_storage_size
    return "0 B" if size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  # Budget and financial methods
  def budget_utilization_rate
    return 0.0 unless budget && budget > 0
    total_budget_limit = budget_categories.sum(:budget_limit)
    return 0.0 if total_budget_limit.zero?

    total_spent = expenses.approved.sum(:amount)
    (total_spent.to_f / total_budget_limit.to_f * 100).round(2)
  end

  def total_expenses
    expenses.approved.sum(:amount)
  end

  def total_revenues
    revenues.confirmed.sum(:amount)
  end

  def net_profit
    total_revenues - total_expenses
  end

  # Task management methods
  def completion_rate
    return 0.0 if tasks.count.zero?
    (tasks.completed.count.to_f / tasks.count * 100).round(2)
  end

  # Vendor management methods
  def vendor_approval_rate
    return 0.0 if vendor_applications.count.zero?
    (vendor_applications.approved.count.to_f / vendor_applications.count * 100).round(2)
  end

  # Authorization methods
  def can_be_edited_by?(user)
    return true if user.admin? || user.system_admin?
    return true if user == self.user
    false
  end

  # UI helper methods
  def status_color
    case status
    when "planning"
      "secondary"
    when "scheduled"
      "info"
    when "active"
      "success"
    when "completed"
      "primary"
    when "cancelled"
      "danger"
    else
      "light"
    end
  end

  # Payment-related methods
  def total_payments_amount
    payments.completed.sum(:amount)
  end

  def total_processing_fees
    payments.completed.sum(:processing_fee)
  end

  def net_revenue
    total_payments_amount - total_processing_fees
  end

  def payment_conversion_rate
    return 0 if payments.count.zero?
    (payments.completed.count.to_f / payments.count * 100).round(2)
  end

  def organizers
    # Festival organizers are users with admin or committee_member roles who have access to this festival
    User.joins(:owned_festivals)
        .where(owned_festivals: { id: self.id })
        .or(User.where(role: [ :admin, :system_admin ]))
  end

  def accessible_by?(user)
    return true if user.admin? || user.system_admin?
    return true if user == self.user # Festival owner
    return true if public? # Public festivals accessible to all

    # Check if user is a member or has vendor application
    vendor_applications.exists?(user: user) ||
    chat_rooms.joins(:chat_room_members).exists?(chat_room_members: { user: user })
  end

  def can_be_modified_by?(user)
    return true if user.admin? || user.system_admin?
    return true if user == self.user # Festival owner
    false
  end

  # LINE連携関連メソッド
  def has_line_integration?
    line_integrations.active_integrations.any?
  end

  def primary_line_integration
    line_integrations.active_integrations.first
  end

  def line_notification_enabled?
    has_line_integration? &&
    line_integrations.any? { |integration| integration.can_send_notifications? }
  end

  def active_line_groups_count
    line_groups.active_groups.count
  end

  def line_messages_count
    line_messages.count
  end

  def recent_line_activity
    line_messages.recent.limit(10)
  end

  def line_created_tasks_count
    tasks.where(created_via_line: true).count
  end

  def line_integration_stats
    return {} unless has_line_integration?

    {
      total_integrations: line_integrations.count,
      active_integrations: line_integrations.active_integrations.count,
      total_groups: line_groups.count,
      active_groups: active_line_groups_count,
      total_messages: line_messages_count,
      processed_messages: line_messages.processed.count,
      created_tasks: line_created_tasks_count,
      last_activity: line_messages.maximum(:line_timestamp) || line_messages.maximum(:created_at)
    }
  end

  private

  def create_default_budget_categories
    default_categories = [
      { name: "会場費", budget_limit: budget * 0.3 },
      { name: "宣伝費", budget_limit: budget * 0.2 },
      { name: "運営費", budget_limit: budget * 0.3 },
      { name: "その他", budget_limit: budget * 0.2 }
    ]

    default_categories.each do |category_attrs|
      budget_categories.create!(category_attrs)
    end
  end

  def create_default_venue
    venues.create!(
      name: "#{name} メイン会場",
      description: "主要な会場エリア",
      capacity: 1000,
      facility_type: "mixed"
    )
  end

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def main_image_format
    return unless main_image.attached?

    unless main_image.blob.content_type.in?([ "image/jpeg", "image/png", "image/webp" ])
      errors.add(:main_image, "must be a JPEG, PNG, or WebP image")
    end

    if main_image.blob.byte_size > 5.megabytes
      errors.add(:main_image, "must be less than 5MB")
    end
  end

  def gallery_images_format
    return unless gallery_images.attached?

    gallery_images.each_with_index do |image, index|
      unless image.blob.content_type.in?([ "image/jpeg", "image/png", "image/webp" ])
        errors.add(:gallery_images, "Image #{index + 1} must be a JPEG, PNG, or WebP")
      end

      if image.blob.byte_size > 5.megabytes
        errors.add(:gallery_images, "Image #{index + 1} must be less than 5MB")
      end
    end

    if gallery_images.count > 10
      errors.add(:gallery_images, "can have maximum 10 images")
    end
  end

  def documents_format
    return unless documents.attached?

    documents.each_with_index do |doc, index|
      unless doc.blob.content_type.in?([ "application/pdf", "text/plain", "application/msword",
                                         "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ])
        errors.add(:documents, "Document #{index + 1} must be PDF, TXT, DOC, or DOCX")
      end

      if doc.blob.byte_size > 10.megabytes
        errors.add(:documents, "Document #{index + 1} must be less than 10MB")
      end
    end

    if documents.count > 20
      errors.add(:documents, "can have maximum 20 documents")
    end
  end
end
