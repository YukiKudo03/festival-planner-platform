class Booth < ApplicationRecord
  belongs_to :venue_area
  belongs_to :festival
  belongs_to :vendor_application, optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validates :booth_number, presence: true, uniqueness: { scope: :festival_id }
  validates :size, presence: true
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :x_position, presence: true, numericality: true
  validates :y_position, presence: true, numericality: true
  validates :rotation, numericality: { in: 0..360 }, allow_nil: true
  validates :status, presence: true

  SIZES = %w[small medium large extra_large custom].freeze
  STATUSES = %w[available reserved assigned occupied maintenance unavailable].freeze

  validates :size, inclusion: { in: SIZES }
  validates :status, inclusion: { in: STATUSES }

  scope :by_status, ->(status) { where(status: status) }
  scope :available, -> { where(status: "available") }
  scope :assigned, -> { where(status: "assigned") }
  scope :occupied, -> { where(status: "occupied") }
  scope :by_size, ->(size) { where(size: size) }
  scope :with_power, -> { where(power_required: true) }
  scope :with_water, -> { where(water_required: true) }
  scope :in_area, ->(area) { where(venue_area: area) }

  def size_text
    case size
    when "small" then "小 (3m×3m)"
    when "medium" then "中 (4m×4m)"
    when "large" then "大 (5m×5m)"
    when "extra_large" then "特大 (6m×6m)"
    when "custom" then "カスタム"
    else size.humanize
    end
  end

  def status_text
    case status
    when "available" then "利用可能"
    when "reserved" then "予約済み"
    when "assigned" then "割り当て済み"
    when "occupied" then "使用中"
    when "maintenance" then "メンテナンス中"
    when "unavailable" then "利用不可"
    else status.humanize
    end
  end

  def status_color
    case status
    when "available" then "success"
    when "reserved" then "warning"
    when "assigned" then "info"
    when "occupied" then "primary"
    when "maintenance" then "secondary"
    when "unavailable" then "danger"
    else "secondary"
    end
  end

  def total_area
    width * height
  end

  def is_available?
    status == "available"
  end

  def is_assigned?
    status == "assigned" && vendor_application.present?
  end

  def assigned_vendor
    vendor_application&.user
  end

  def center_point
    {
      x: x_position + (width / 2),
      y: y_position + (height / 2)
    }
  end

  def corners
    [
      { x: x_position, y: y_position },                    # top-left
      { x: x_position + width, y: y_position },            # top-right
      { x: x_position + width, y: y_position + height },   # bottom-right
      { x: x_position, y: y_position + height }            # bottom-left
    ]
  end

  def overlaps_with?(other_booth)
    return false if other_booth == self

    !(x_position + width <= other_booth.x_position ||
      other_booth.x_position + other_booth.width <= x_position ||
      y_position + height <= other_booth.y_position ||
      other_booth.y_position + other_booth.height <= y_position)
  end

  def distance_to(other_booth)
    center = center_point
    other_center = other_booth.center_point

    dx = other_center[:x] - center[:x]
    dy = other_center[:y] - center[:y]

    Math.sqrt(dx**2 + dy**2).round(2)
  end

  def fits_within_area?
    return false unless venue_area

    x_position >= venue_area.x_position &&
    y_position >= venue_area.y_position &&
    (x_position + width) <= (venue_area.x_position + venue_area.width) &&
    (y_position + height) <= (venue_area.y_position + venue_area.height)
  end

  def assign_to_vendor!(vendor_application)
    return false unless is_available?
    return false unless vendor_application.approved?

    transaction do
      update!(
        vendor_application: vendor_application,
        status: "assigned"
      )

      # 通知送信
      NotificationService.create_notification(
        recipient: vendor_application.user,
        sender: festival.user,
        notifiable: self,
        notification_type: "booth_assigned",
        title: "ブースが割り当てられました",
        message: "ブース番号: #{booth_number} (#{venue_area.name})"
      )
    end
  end

  def unassign_from_vendor!
    return false unless is_assigned?

    old_vendor = vendor_application

    transaction do
      update!(
        vendor_application: nil,
        status: "available"
      )

      # 通知送信
      if old_vendor
        NotificationService.create_notification(
          recipient: old_vendor.user,
          sender: festival.user,
          notifiable: self,
          notification_type: "booth_unassigned",
          title: "ブースの割り当てが解除されました",
          message: "ブース番号: #{booth_number} (#{venue_area.name})"
        )
      end
    end
  end

  def mark_as_occupied!
    return false unless status.in?([ "assigned", "reserved" ])
    update!(status: "occupied")
  end

  def mark_as_available!
    return false if vendor_application.present?
    update!(status: "available")
  end

  def can_be_modified_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    return true if festival.user == user
    false
  end

  def requirements_summary
    requirements = []
    requirements << "電源" if power_required?
    requirements << "給水" if water_required?
    requirements << special_requirements if special_requirements.present?

    requirements.any? ? requirements.join(", ") : "特別な要件なし"
  end

  def self.generate_booth_number(festival_id, area_index, booth_index)
    area_prefix = (area_index + 1).to_s.rjust(2, "0")
    booth_number = (booth_index + 1).to_s.rjust(3, "0")
    "#{area_prefix}-#{booth_number}"
  end
end
