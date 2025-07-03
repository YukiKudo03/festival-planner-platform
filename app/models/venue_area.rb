class VenueArea < ApplicationRecord
  belongs_to :venue
  has_many :booths, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :area_type, presence: true
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :x_position, presence: true, numericality: true
  validates :y_position, presence: true, numericality: true
  validates :rotation, numericality: { in: 0..360 }, allow_nil: true
  validates :capacity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  AREA_TYPES = %w[vendor_area food_court stage seating performance_area entrance parking restroom first_aid storage staff_area vip_area].freeze
  validates :area_type, inclusion: { in: AREA_TYPES }

  scope :by_type, ->(type) { where(area_type: type) }
  scope :vendor_areas, -> { where(area_type: 'vendor_area') }
  scope :ordered_by_position, -> { order(:x_position, :y_position) }

  def area_type_text
    case area_type
    when 'vendor_area' then 'ベンダーエリア'
    when 'food_court' then 'フードコート'
    when 'stage' then 'ステージ'
    when 'seating' then '観客席'
    when 'performance_area' then 'パフォーマンスエリア'
    when 'entrance' then '入場口'
    when 'parking' then '駐車場'
    when 'restroom' then 'トイレ'
    when 'first_aid' then '救護所'
    when 'storage' then '倉庫'
    when 'staff_area' then 'スタッフエリア'
    when 'vip_area' then 'VIPエリア'
    else area_type.humanize
    end
  end

  def total_area
    width * height
  end

  def occupied_booths_count
    booths.where.not(status: ['available', 'reserved']).count
  end

  def available_booths_count
    booths.where(status: 'available').count
  end

  def occupancy_rate
    total = booths.count
    return 0 if total.zero?
    
    occupied = occupied_booths_count
    (occupied.to_f / total * 100).round(2)
  end

  def center_point
    {
      x: x_position + (width / 2),
      y: y_position + (height / 2)
    }
  end

  def overlaps_with?(other_area)
    return false if other_area == self
    
    # Simple bounding box check
    !(x_position + width < other_area.x_position ||
      other_area.x_position + other_area.width < x_position ||
      y_position + height < other_area.y_position ||
      other_area.y_position + other_area.height < y_position)
  end

  def distance_to(other_area)
    center = center_point
    other_center = other_area.center_point
    
    dx = other_center[:x] - center[:x]
    dy = other_center[:y] - center[:y]
    
    Math.sqrt(dx**2 + dy**2).round(2)
  end

  def can_be_modified_by?(user)
    venue.can_be_modified_by?(user)
  end
end
