class LayoutManagementService
  def initialize(venue)
    @venue = venue
  end

  def generate_layout_data
    {
      venue: venue_data,
      venue_areas: venue_areas_data,
      booths: booths_data,
      layout_elements: layout_elements_data,
      metadata: layout_metadata
    }
  end

  def auto_arrange_booths(area, booth_params)
    return { success: false, error: 'エリアが指定されていません' } unless area
    return { success: false, error: 'ブースパラメータが不正です' } unless valid_booth_params?(booth_params)

    booth_width = booth_params[:width].to_f
    booth_height = booth_params[:height].to_f
    spacing = booth_params[:spacing]&.to_f || 2.0
    
    # Calculate grid layout
    booths_per_row = ((area.width - spacing) / (booth_width + spacing)).floor
    booths_per_col = ((area.height - spacing) / (booth_height + spacing)).floor
    
    return { success: false, error: 'エリアが小さすぎます' } if booths_per_row <= 0 || booths_per_col <= 0

    created_booths = []
    
    ActiveRecord::Base.transaction do
      # Clear existing booths if requested
      if booth_params[:clear_existing]
        area.booths.destroy_all
      end
      
      (0...booths_per_col).each do |row|
        (0...booths_per_row).each do |col|
          booth_x = area.x_position + spacing + col * (booth_width + spacing)
          booth_y = area.y_position + spacing + row * (booth_height + spacing)
          
          booth_number = Booth.generate_booth_number(@venue.festival.id, area.id, created_booths.count)
          
          booth = area.booths.create!(
            festival: @venue.festival,
            name: "ブース #{booth_number}",
            booth_number: booth_number,
            size: booth_params[:size] || 'medium',
            width: booth_width,
            height: booth_height,
            x_position: booth_x,
            y_position: booth_y,
            status: 'available',
            power_required: booth_params[:power_required] || false,
            water_required: booth_params[:water_required] || false
          )
          
          created_booths << booth
        end
      end
    end
    
    {
      success: true,
      booths_created: created_booths.count,
      layout: "#{booths_per_row}×#{booths_per_col}",
      booths: created_booths
    }
  end

  def detect_overlaps
    overlaps = []
    elements = @venue.layout_elements.visible.includes(:venue)
    areas = @venue.venue_areas.includes(:venue)
    booths = @venue.booths.includes(:venue_area)
    
    # Check element overlaps
    elements.combination(2) do |elem1, elem2|
      if elem1.overlaps_with?(elem2)
        overlaps << {
          type: 'element_overlap',
          element1: element_summary(elem1),
          element2: element_summary(elem2),
          severity: 'warning'
        }
      end
    end
    
    # Check area overlaps
    areas.combination(2) do |area1, area2|
      if area1.overlaps_with?(area2)
        overlaps << {
          type: 'area_overlap',
          area1: area_summary(area1),
          area2: area_summary(area2),
          severity: 'error'
        }
      end
    end
    
    # Check booth overlaps within areas
    booths.group_by(&:venue_area).each do |area, area_booths|
      area_booths.combination(2) do |booth1, booth2|
        if booth1.overlaps_with?(booth2)
          overlaps << {
            type: 'booth_overlap',
            booth1: booth_summary(booth1),
            booth2: booth_summary(booth2),
            area: area.name,
            severity: 'error'
          }
        end
      end
    end
    
    overlaps
  end

  def optimize_layout
    optimization_results = {
      space_utilization: calculate_space_utilization,
      accessibility_score: calculate_accessibility_score,
      flow_efficiency: calculate_flow_efficiency,
      suggestions: generate_layout_suggestions
    }
    
    optimization_results[:overall_score] = calculate_overall_score(optimization_results)
    optimization_results
  end

  def export_layout(format = :json)
    layout_data = generate_layout_data
    
    case format
    when :json
      layout_data.to_json
    when :svg
      generate_svg_layout(layout_data)
    when :csv
      generate_csv_layout(layout_data)
    else
      layout_data
    end
  end

  def import_layout(layout_data, options = {})
    return { success: false, error: 'レイアウトデータが不正です' } unless valid_layout_data?(layout_data)
    
    ActiveRecord::Base.transaction do
      if options[:clear_existing]
        @venue.layout_elements.destroy_all
        @venue.venue_areas.destroy_all
      end
      
      import_results = {
        venue_areas: 0,
        booths: 0,
        layout_elements: 0
      }
      
      # Import venue areas
      if layout_data[:venue_areas]
        layout_data[:venue_areas].each do |area_data|
          area = @venue.venue_areas.create!(
            name: area_data[:name],
            description: area_data[:description],
            area_type: area_data[:area_type],
            width: area_data[:width],
            height: area_data[:height],
            x_position: area_data[:x_position],
            y_position: area_data[:y_position],
            rotation: area_data[:rotation],
            color: area_data[:color],
            capacity: area_data[:capacity]
          )
          import_results[:venue_areas] += 1
          
          # Import booths for this area
          if area_data[:booths]
            area_data[:booths].each do |booth_data|
              area.booths.create!(
                festival: @venue.festival,
                name: booth_data[:name],
                booth_number: booth_data[:booth_number],
                size: booth_data[:size],
                width: booth_data[:width],
                height: booth_data[:height],
                x_position: booth_data[:x_position],
                y_position: booth_data[:y_position],
                rotation: booth_data[:rotation],
                status: booth_data[:status] || 'available',
                power_required: booth_data[:power_required] || false,
                water_required: booth_data[:water_required] || false,
                special_requirements: booth_data[:special_requirements],
                setup_instructions: booth_data[:setup_instructions]
              )
              import_results[:booths] += 1
            end
          end
        end
      end
      
      # Import layout elements
      if layout_data[:layout_elements]
        layout_data[:layout_elements].each do |element_data|
          @venue.layout_elements.create!(
            element_type: element_data[:element_type],
            name: element_data[:name],
            description: element_data[:description],
            x_position: element_data[:x_position],
            y_position: element_data[:y_position],
            width: element_data[:width],
            height: element_data[:height],
            rotation: element_data[:rotation],
            color: element_data[:color],
            properties: element_data[:properties]&.to_json,
            layer: element_data[:layer] || 0,
            locked: element_data[:locked] || false,
            visible: element_data[:visible] || true
          )
          import_results[:layout_elements] += 1
        end
      end
      
      { success: true, imported: import_results }
    end
  rescue => e
    { success: false, error: e.message }
  end

  def generate_booth_assignment_recommendations(vendor_requirements)
    available_booths = @venue.booths.available.includes(:venue_area)
    recommendations = []
    
    vendor_requirements.each do |vendor_id, requirements|
      matching_booths = available_booths.select do |booth|
        meets_size_requirement?(booth, requirements[:size]) &&
        meets_power_requirement?(booth, requirements[:power_required]) &&
        meets_water_requirement?(booth, requirements[:water_required]) &&
        meets_area_preference?(booth, requirements[:preferred_area_type])
      end
      
      # Score and rank booths
      scored_booths = matching_booths.map do |booth|
        score = calculate_booth_score(booth, requirements)
        { booth: booth, score: score }
      end.sort_by { |item| -item[:score] }
      
      recommendations << {
        vendor_id: vendor_id,
        recommended_booths: scored_booths.first(5),
        total_matches: scored_booths.count
      }
    end
    
    recommendations
  end

  private

  def venue_data
    {
      id: @venue.id,
      name: @venue.name,
      description: @venue.description,
      capacity: @venue.capacity,
      facility_type: @venue.facility_type,
      coordinates: @venue.coordinates
    }
  end

  def venue_areas_data
    @venue.venue_areas.map do |area|
      {
        id: area.id,
        name: area.name,
        description: area.description,
        area_type: area.area_type,
        width: area.width,
        height: area.height,
        x_position: area.x_position,
        y_position: area.y_position,
        rotation: area.rotation,
        color: area.color,
        capacity: area.capacity,
        booth_count: area.booths.count,
        occupancy_rate: area.occupancy_rate
      }
    end
  end

  def booths_data
    @venue.booths.includes(:venue_area, :vendor_application).map do |booth|
      {
        id: booth.id,
        name: booth.name,
        booth_number: booth.booth_number,
        size: booth.size,
        width: booth.width,
        height: booth.height,
        x_position: booth.x_position,
        y_position: booth.y_position,
        rotation: booth.rotation,
        status: booth.status,
        power_required: booth.power_required,
        water_required: booth.water_required,
        special_requirements: booth.special_requirements,
        venue_area: {
          id: booth.venue_area.id,
          name: booth.venue_area.name
        },
        vendor: booth.vendor_application ? {
          id: booth.vendor_application.id,
          user_name: booth.vendor_application.user.name
        } : nil
      }
    end
  end

  def layout_elements_data
    @venue.layout_elements.visible.ordered_by_layer.map do |element|
      {
        id: element.id,
        element_type: element.element_type,
        name: element.name,
        description: element.description,
        x_position: element.x_position,
        y_position: element.y_position,
        width: element.width,
        height: element.height,
        rotation: element.rotation,
        color: element.color,
        properties: element.properties_hash,
        layer: element.layer,
        locked: element.locked,
        visible: element.visible
      }
    end
  end

  def layout_metadata
    bounds = @venue.layout_bounds
    {
      bounds: bounds,
      total_area: @venue.total_layout_area,
      total_booths: @venue.booths.count,
      available_booths: @venue.available_booths_count,
      occupancy_rate: @venue.occupancy_rate,
      last_updated: [@venue.updated_at, @venue.venue_areas.maximum(:updated_at), @venue.layout_elements.maximum(:updated_at)].compact.max
    }
  end

  def valid_booth_params?(params)
    params[:width].present? && params[:height].present? &&
    params[:width].to_f > 0 && params[:height].to_f > 0
  end

  def valid_layout_data?(data)
    data.is_a?(Hash) && (data[:venue_areas] || data[:layout_elements])
  end

  def element_summary(element)
    {
      id: element.id,
      name: element.name,
      type: element.element_type,
      position: { x: element.x_position, y: element.y_position },
      size: { width: element.width, height: element.height }
    }
  end

  def area_summary(area)
    {
      id: area.id,
      name: area.name,
      type: area.area_type,
      position: { x: area.x_position, y: area.y_position },
      size: { width: area.width, height: area.height }
    }
  end

  def booth_summary(booth)
    {
      id: booth.id,
      number: booth.booth_number,
      position: { x: booth.x_position, y: booth.y_position },
      size: { width: booth.width, height: booth.height }
    }
  end

  def calculate_space_utilization
    total_venue_area = @venue.total_layout_area
    return 0 if total_venue_area.zero?
    
    used_area = @venue.venue_areas.sum(&:total_area) + @venue.layout_elements.visible.sum(&:total_area)
    (used_area / total_venue_area * 100).round(2)
  end

  def calculate_accessibility_score
    # Simple accessibility scoring based on proximity to entrances and exits
    entrances = @venue.layout_elements.where(element_type: ['entrance', 'exit'])
    return 0 if entrances.empty?
    
    booth_scores = @venue.booths.map do |booth|
      min_distance = entrances.map { |entrance| booth.distance_to(entrance) }.min
      # Score inversely related to distance (closer = better)
      [100 - (min_distance / 10), 0].max
    end
    
    booth_scores.any? ? (booth_scores.sum / booth_scores.count).round(2) : 0
  end

  def calculate_flow_efficiency
    # Calculate based on path width and connectivity
    paths = @venue.layout_elements.where(element_type: ['path', 'walkway'])
    total_path_area = paths.sum(&:total_area)
    
    # Basic flow efficiency based on path coverage
    venue_area = @venue.total_layout_area
    return 0 if venue_area.zero?
    
    path_coverage = (total_path_area / venue_area * 100).round(2)
    [path_coverage, 100].min  # Cap at 100
  end

  def generate_layout_suggestions
    suggestions = []
    
    # Check for accessibility issues
    if calculate_accessibility_score < 50
      suggestions << {
        type: 'accessibility',
        priority: 'high',
        message: '一部のブースが入場口から遠すぎます。アクセス性を改善することを検討してください。'
      }
    end
    
    # Check for space utilization
    if calculate_space_utilization < 30
      suggestions << {
        type: 'space_utilization',
        priority: 'medium',
        message: 'スペースの使用率が低いです。より多くのブースやエリアを配置できます。'
      }
    end
    
    # Check for overlaps
    overlaps = detect_overlaps
    if overlaps.any?
      suggestions << {
        type: 'overlaps',
        priority: 'high',
        message: "#{overlaps.count}件の重複が検出されました。レイアウトを調整してください。"
      }
    end
    
    suggestions
  end

  def calculate_overall_score(results)
    weights = {
      space_utilization: 0.3,
      accessibility_score: 0.4,
      flow_efficiency: 0.3
    }
    
    weighted_sum = weights.sum do |metric, weight|
      (results[metric] || 0) * weight
    end
    
    # Penalty for critical issues
    penalty = results[:suggestions].count { |s| s[:priority] == 'high' } * 10
    
    [weighted_sum - penalty, 0].max.round(2)
  end

  def meets_size_requirement?(booth, required_size)
    return true unless required_size
    
    size_hierarchy = { 'small' => 1, 'medium' => 2, 'large' => 3, 'extra_large' => 4, 'custom' => 5 }
    booth_size_value = size_hierarchy[booth.size] || 0
    required_size_value = size_hierarchy[required_size] || 0
    
    booth_size_value >= required_size_value
  end

  def meets_power_requirement?(booth, required)
    return true unless required
    booth.power_required?
  end

  def meets_water_requirement?(booth, required)
    return true unless required
    booth.water_required?
  end

  def meets_area_preference?(booth, preferred_area_type)
    return true unless preferred_area_type
    booth.venue_area.area_type == preferred_area_type
  end

  def calculate_booth_score(booth, requirements)
    score = 100
    
    # Bonus for exact size match
    if booth.size == requirements[:size]
      score += 20
    end
    
    # Bonus for meeting power requirements
    if requirements[:power_required] && booth.power_required?
      score += 15
    end
    
    # Bonus for meeting water requirements
    if requirements[:water_required] && booth.water_required?
      score += 15
    end
    
    # Bonus for preferred area type
    if booth.venue_area.area_type == requirements[:preferred_area_type]
      score += 25
    end
    
    score
  end

  def generate_svg_layout(layout_data)
    # SVG generation would be implemented here
    # This is a placeholder for SVG export functionality
    "<!-- SVG Layout Export Placeholder -->"
  end

  def generate_csv_layout(layout_data)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Type', 'Name', 'X', 'Y', 'Width', 'Height', 'Status', 'Notes']
      
      layout_data[:venue_areas].each do |area|
        csv << ['Area', area[:name], area[:x_position], area[:y_position], area[:width], area[:height], area[:area_type], area[:description]]
      end
      
      layout_data[:booths].each do |booth|
        csv << ['Booth', booth[:name], booth[:x_position], booth[:y_position], booth[:width], booth[:height], booth[:status], booth[:special_requirements]]
      end
      
      layout_data[:layout_elements].each do |element|
        csv << ['Element', element[:name], element[:x_position], element[:y_position], element[:width], element[:height], element[:element_type], element[:description]]
      end
    end
  end
end