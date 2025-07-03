class LayoutElement < ApplicationRecord
  belongs_to :venue

  validates :name, presence: true, length: { maximum: 100 }
  validates :element_type, presence: true
  validates :x_position, presence: true, numericality: true
  validates :y_position, presence: true, numericality: true
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :rotation, numericality: { in: 0..360 }, allow_nil: true
  validates :layer, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  ELEMENT_TYPES = %w[
    stage platform seating_area entrance exit emergency_exit
    restroom first_aid info_booth security_post 
    food_area vendor_area parking_area storage_area
    barrier fence gate path walkway
    decoration signage screen speaker
    power_source water_source waste_disposal
    tree building structure equipment
    custom
  ].freeze

  validates :element_type, inclusion: { in: ELEMENT_TYPES }

  scope :by_type, ->(type) { where(element_type: type) }
  scope :by_layer, ->(layer) { where(layer: layer) }
  scope :visible, -> { where(visible: true) }
  scope :unlocked, -> { where(locked: false) }
  scope :ordered_by_layer, -> { order(:layer, :created_at) }

  def element_type_text
    case element_type
    when 'stage' then 'ステージ'
    when 'platform' then 'プラットフォーム'
    when 'seating_area' then '観客席'
    when 'entrance' then '入場口'
    when 'exit' then '出口'
    when 'emergency_exit' then '緊急出口'
    when 'restroom' then 'トイレ'
    when 'first_aid' then '救護所'
    when 'info_booth' then 'インフォメーション'
    when 'security_post' then '警備所'
    when 'food_area' then 'フードエリア'
    when 'vendor_area' then 'ベンダーエリア'
    when 'parking_area' then '駐車場'
    when 'storage_area' then '倉庫'
    when 'barrier' then 'バリア'
    when 'fence' then 'フェンス'
    when 'gate' then 'ゲート'
    when 'path' then '通路'
    when 'walkway' then '歩道'
    when 'decoration' then '装飾'
    when 'signage' then 'サイネージ'
    when 'screen' then 'スクリーン'
    when 'speaker' then 'スピーカー'
    when 'power_source' then '電源'
    when 'water_source' then '給水'
    when 'waste_disposal' then 'ゴミ箱'
    when 'tree' then '樹木'
    when 'building' then '建物'
    when 'structure' then '構造物'
    when 'equipment' then '設備'
    when 'custom' then 'カスタム'
    else element_type.humanize
    end
  end

  def center_point
    {
      x: x_position + (width / 2),
      y: y_position + (height / 2)
    }
  end

  def corners
    cos_r = Math.cos(rotation_in_radians)
    sin_r = Math.sin(rotation_in_radians)
    
    # Original corners relative to top-left
    corners = [
      { x: 0, y: 0 },           # top-left
      { x: width, y: 0 },       # top-right
      { x: width, y: height },  # bottom-right
      { x: 0, y: height }       # bottom-left
    ]
    
    # Rotate around center and translate to world position
    center = { x: width / 2, y: height / 2 }
    
    corners.map do |corner|
      # Translate to center
      rel_x = corner[:x] - center[:x]
      rel_y = corner[:y] - center[:y]
      
      # Rotate
      rotated_x = rel_x * cos_r - rel_y * sin_r
      rotated_y = rel_x * sin_r + rel_y * cos_r
      
      # Translate back and to world position
      {
        x: x_position + center[:x] + rotated_x,
        y: y_position + center[:y] + rotated_y
      }
    end
  end

  def bounding_box
    if rotation.nil? || rotation == 0
      {
        min_x: x_position,
        min_y: y_position,
        max_x: x_position + width,
        max_y: y_position + height
      }
    else
      corners_coords = corners
      x_coords = corners_coords.map { |c| c[:x] }
      y_coords = corners_coords.map { |c| c[:y] }
      
      {
        min_x: x_coords.min,
        max_x: x_coords.max,
        min_y: y_coords.min,
        max_y: y_coords.max
      }
    end
  end

  def overlaps_with?(other_element)
    return false if other_element == self
    return false unless visible? && other_element.visible?
    
    # Simple bounding box check for performance
    self_bounds = bounding_box
    other_bounds = other_element.bounding_box
    
    !(self_bounds[:max_x] <= other_bounds[:min_x] ||
      other_bounds[:max_x] <= self_bounds[:min_x] ||
      self_bounds[:max_y] <= other_bounds[:min_y] ||
      other_bounds[:max_y] <= self_bounds[:min_y])
  end

  def distance_to(other_element)
    center = center_point
    other_center = other_element.center_point
    
    dx = other_center[:x] - center[:x]
    dy = other_center[:y] - center[:y]
    
    Math.sqrt(dx**2 + dy**2).round(2)
  end

  def total_area
    width * height
  end

  def move_to(new_x, new_y)
    update(x_position: new_x, y_position: new_y)
  end

  def resize_to(new_width, new_height)
    update(width: new_width, height: new_height)
  end

  def rotate_to(new_rotation)
    update(rotation: new_rotation % 360)
  end

  def toggle_visibility!
    update!(visible: !visible)
  end

  def toggle_lock!
    update!(locked: !locked)
  end

  def bring_to_front!
    max_layer = venue.layout_elements.maximum(:layer) || 0
    update!(layer: max_layer + 1)
  end

  def send_to_back!
    min_layer = venue.layout_elements.minimum(:layer) || 0
    update!(layer: [min_layer - 1, 0].max)
  end

  def clone_element(new_name = nil)
    new_element = self.dup
    new_element.name = new_name || "#{name} (コピー)"
    new_element.x_position += 20  # Offset copy
    new_element.y_position += 20
    new_element.layer = (venue.layout_elements.maximum(:layer) || 0) + 1
    new_element.save
    new_element
  end

  def can_be_modified_by?(user)
    return false if locked?
    venue.can_be_modified_by?(user)
  end

  def properties_hash
    return {} if properties.blank?
    
    begin
      JSON.parse(properties)
    rescue JSON::ParserError
      {}
    end
  end

  def update_properties(new_properties)
    self.properties = new_properties.to_json
    save
  end

  def self.create_default_elements_for(venue)
    default_elements = [
      {
        element_type: 'entrance',
        name: 'メインエントランス',
        x_position: 50,
        y_position: 10,
        width: 40,
        height: 20,
        color: '#4CAF50',
        layer: 1
      },
      {
        element_type: 'stage',
        name: 'メインステージ',
        x_position: 200,
        y_position: 50,
        width: 100,
        height: 60,
        color: '#9C27B0',
        layer: 1
      },
      {
        element_type: 'restroom',
        name: 'トイレ',
        x_position: 10,
        y_position: 50,
        width: 30,
        height: 20,
        color: '#2196F3',
        layer: 1
      }
    ]
    
    default_elements.each do |element_data|
      venue.layout_elements.create!(element_data)
    end
  end

  private

  def rotation_in_radians
    (rotation || 0) * Math::PI / 180
  end
end
