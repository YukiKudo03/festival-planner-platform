class Venue < ApplicationRecord
  belongs_to :festival
  has_many :venue_areas, dependent: :destroy
  has_many :layout_elements, dependent: :destroy
  has_many :booths, through: :venue_areas

  validates :name, presence: true, length: { maximum: 100 }
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :facility_type, presence: true
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true

  FACILITY_TYPES = %w[indoor outdoor mixed pavilion arena stadium park convention_center].freeze
  validates :facility_type, inclusion: { in: FACILITY_TYPES }

  scope :by_type, ->(type) { where(facility_type: type) }
  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }

  def facility_type_text
    case facility_type
    when 'indoor' then '屋内'
    when 'outdoor' then '屋外'
    when 'mixed' then '屋内外複合'
    when 'pavilion' then 'パビリオン'
    when 'arena' then 'アリーナ'
    when 'stadium' then 'スタジアム'
    when 'park' then '公園'
    when 'convention_center' then 'コンベンションセンター'
    else facility_type.humanize
    end
  end

  def total_booth_capacity
    venue_areas.sum(:capacity)
  end

  def occupied_booths_count
    booths.where.not(status: ['available', 'reserved']).count
  end

  def available_booths_count
    booths.where(status: ['available']).count
  end

  def occupancy_rate
    total = booths.count
    return 0 if total.zero?
    
    occupied = occupied_booths_count
    (occupied.to_f / total * 100).round(2)
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def coordinates
    return nil unless has_coordinates?
    [latitude, longitude]
  end

  def distance_from(other_venue)
    return nil unless has_coordinates? && other_venue.has_coordinates?
    
    # Haversine formula for distance calculation
    rad_per_deg = Math::PI / 180
    rkm = 6371  # Earth radius in kilometers
    
    dlat_rad = (other_venue.latitude - latitude) * rad_per_deg
    dlon_rad = (other_venue.longitude - longitude) * rad_per_deg
    
    lat1_rad = latitude * rad_per_deg
    lat2_rad = other_venue.latitude * rad_per_deg
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    
    (rkm * c).round(2)
  end

  def can_be_modified_by?(user)
    return false unless user
    return true if user.admin? || user.committee_member?
    festival.user == user
  end

  def layout_bounds
    return { min_x: 0, min_y: 0, max_x: 0, max_y: 0 } if layout_elements.empty?
    
    elements = layout_elements.visible
    {
      min_x: elements.minimum('x_position') || 0,
      min_y: elements.minimum('y_position') || 0,
      max_x: elements.maximum('x_position + width') || 0,
      max_y: elements.maximum('y_position + height') || 0
    }
  end

  def total_layout_area
    bounds = layout_bounds
    (bounds[:max_x] - bounds[:min_x]) * (bounds[:max_y] - bounds[:min_y])
  end

  def generate_booth_numbers
    venue_areas.includes(:booths).each_with_index do |area, area_index|
      area.booths.each_with_index do |booth, booth_index|
        area_prefix = (area_index + 1).to_s.rjust(2, '0')
        booth_number = (booth_index + 1).to_s.rjust(3, '0')
        booth.update(booth_number: "#{area_prefix}-#{booth_number}")
      end
    end
  end
end
