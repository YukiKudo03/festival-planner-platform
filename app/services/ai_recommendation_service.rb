# frozen_string_literal: true

# AI-powered recommendation service for festival planning optimization
# Provides attendance prediction, vendor layout optimization, and budget allocation recommendations
class AiRecommendationService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Configuration for AI models and thresholds
  ATTENDANCE_PREDICTION_FACTORS = {
    weather: 0.25,
    historical_data: 0.35,
    marketing_reach: 0.20,
    competitor_events: 0.10,
    seasonal_trends: 0.10
  }.freeze

  LAYOUT_OPTIMIZATION_CONSTRAINTS = {
    min_distance_between_vendors: 3.0, # meters
    max_walking_distance_to_facilities: 50.0, # meters
    crowd_flow_efficiency: 0.8, # efficiency score
    emergency_access_width: 4.0 # meters
  }.freeze

  BUDGET_ALLOCATION_CATEGORIES = %w[
    venue_costs
    marketing_promotion
    security_safety
    infrastructure
    entertainment
    food_beverage
    logistics
    contingency
  ].freeze

  # Predicts festival attendance based on multiple factors
  # @param festival [Festival] The festival for prediction
  # @param weather_data [Hash] Weather forecast data
  # @param historical_data [Array<Hash>] Historical attendance data
  # @return [Hash] Prediction results with confidence interval
  def predict_attendance(festival, weather_data: {}, historical_data: [])
    return error_response('Festival is required') unless festival

    base_prediction = calculate_base_attendance(festival, historical_data)
    weather_adjustment = calculate_weather_impact(weather_data)
    marketing_impact = calculate_marketing_impact(festival)
    competition_factor = calculate_competition_factor(festival)
    seasonal_adjustment = calculate_seasonal_adjustment(festival)

    predicted_attendance = apply_prediction_factors(
      base_prediction,
      weather_adjustment: weather_adjustment,
      marketing_impact: marketing_impact,
      competition_factor: competition_factor,
      seasonal_adjustment: seasonal_adjustment
    )

    confidence_score = calculate_confidence_score(festival, historical_data)

    {
      success: true,
      predicted_attendance: predicted_attendance.round,
      confidence_score: confidence_score,
      factors: {
        base_prediction: base_prediction,
        weather_impact: weather_adjustment,
        marketing_impact: marketing_impact,
        competition_factor: competition_factor,
        seasonal_adjustment: seasonal_adjustment
      },
      recommendations: generate_attendance_recommendations(predicted_attendance, festival)
    }
  rescue StandardError => e
    Rails.logger.error "Attendance prediction error: #{e.message}"
    error_response("Prediction failed: #{e.message}")
  end

  # Optimizes vendor layout for maximum efficiency and customer experience
  # @param venue [Venue] The venue for layout optimization
  # @param vendors [Array<VendorApplication>] Approved vendor applications
  # @param constraints [Hash] Additional constraints for optimization
  # @return [Hash] Optimized layout with vendor positions
  def optimize_vendor_layout(venue, vendors, constraints: {})
    return error_response('Venue and vendors are required') unless venue && vendors.any?

    # Merge default constraints with custom ones
    optimization_constraints = LAYOUT_OPTIMIZATION_CONSTRAINTS.merge(constraints)
    
    # Analyze venue space and capacity
    venue_analysis = analyze_venue_space(venue)
    return error_response('Venue analysis failed') unless venue_analysis[:success]

    # Categorize vendors by type and space requirements
    vendor_categories = categorize_vendors(vendors)
    
    # Generate optimal layout using constraint-based optimization
    layout_solution = generate_optimal_layout(
      venue_analysis: venue_analysis,
      vendor_categories: vendor_categories,
      constraints: optimization_constraints
    )

    # Validate layout meets safety and accessibility requirements
    validation_result = validate_layout(layout_solution, optimization_constraints)
    
    if validation_result[:valid]
      {
        success: true,
        layout: layout_solution,
        efficiency_score: calculate_layout_efficiency(layout_solution),
        crowd_flow_score: calculate_crowd_flow_score(layout_solution),
        accessibility_score: calculate_accessibility_score(layout_solution),
        recommendations: generate_layout_recommendations(layout_solution),
        alternative_layouts: generate_alternative_layouts(venue_analysis, vendor_categories, 2)
      }
    else
      error_response("Layout validation failed: #{validation_result[:errors].join(', ')}")
    end
  rescue StandardError => e
    Rails.logger.error "Layout optimization error: #{e.message}"
    error_response("Layout optimization failed: #{e.message}")
  end

  # Recommends optimal budget allocation across categories
  # @param festival [Festival] The festival for budget planning
  # @param total_budget [Numeric] Total available budget
  # @param historical_performance [Array<Hash>] Historical budget performance data
  # @return [Hash] Recommended budget allocation with rationale
  def recommend_budget_allocation(festival, total_budget, historical_performance: [])
    return error_response('Festival and budget are required') unless festival && total_budget&.positive?

    # Analyze festival characteristics for budget priorities
    festival_profile = analyze_festival_profile(festival)
    
    # Calculate base allocation percentages
    base_allocation = calculate_base_budget_allocation(festival_profile)
    
    # Adjust based on historical performance
    performance_adjustments = calculate_performance_adjustments(historical_performance)
    
    # Apply risk and opportunity factors
    risk_adjustments = calculate_risk_adjustments(festival)
    
    # Generate final allocation recommendation
    recommended_allocation = apply_budget_adjustments(
      base_allocation,
      performance_adjustments,
      risk_adjustments,
      total_budget
    )

    # Validate allocation totals and constraints
    validation_result = validate_budget_allocation(recommended_allocation, total_budget)
    
    if validation_result[:valid]
      {
        success: true,
        total_budget: total_budget,
        recommended_allocation: recommended_allocation,
        allocation_rationale: generate_allocation_rationale(recommended_allocation, festival_profile),
        risk_assessment: assess_budget_risks(recommended_allocation, festival),
        optimization_opportunities: identify_optimization_opportunities(recommended_allocation),
        contingency_plan: generate_contingency_budget_plan(recommended_allocation)
      }
    else
      error_response("Budget allocation validation failed: #{validation_result[:errors].join(', ')}")
    end
  rescue StandardError => e
    Rails.logger.error "Budget allocation error: #{e.message}"
    error_response("Budget allocation failed: #{e.message}")
  end

  # Provides comprehensive risk assessment and mitigation recommendations
  # @param festival [Festival] The festival for risk assessment
  # @param risk_categories [Array<String>] Specific risk categories to assess
  # @return [Hash] Risk assessment with mitigation strategies
  def assess_festival_risks(festival, risk_categories: %w[weather safety security financial operational])
    return error_response('Festival is required') unless festival

    risk_assessment = {}
    
    risk_categories.each do |category|
      risk_assessment[category] = assess_risk_category(festival, category)
    end

    overall_risk_score = calculate_overall_risk_score(risk_assessment)
    critical_risks = identify_critical_risks(risk_assessment)
    mitigation_strategies = generate_mitigation_strategies(risk_assessment)

    {
      success: true,
      overall_risk_score: overall_risk_score,
      risk_level: categorize_risk_level(overall_risk_score),
      category_assessments: risk_assessment,
      critical_risks: critical_risks,
      mitigation_strategies: mitigation_strategies,
      monitoring_recommendations: generate_monitoring_recommendations(risk_assessment),
      contingency_plans: generate_risk_contingency_plans(critical_risks)
    }
  rescue StandardError => e
    Rails.logger.error "Risk assessment error: #{e.message}"
    error_response("Risk assessment failed: #{e.message}")
  end

  private

  # Calculate base attendance prediction from historical data
  def calculate_base_attendance(festival, historical_data)
    if historical_data.any?
      # Use weighted average of similar events
      similar_events = filter_similar_events(festival, historical_data)
      return similar_events.empty? ? estimate_from_festival_capacity(festival) : weighted_average_attendance(similar_events)
    end
    
    estimate_from_festival_capacity(festival)
  end

  # Filter historical events similar to the current festival
  def filter_similar_events(festival, historical_data)
    historical_data.select do |event|
      similarity_score(festival, event) > 0.6
    end
  end

  # Calculate similarity score between festivals
  def similarity_score(festival, historical_event)
    scores = []
    
    # Venue capacity similarity
    if festival.venue&.capacity && historical_event[:capacity]
      capacity_ratio = [festival.venue.capacity, historical_event[:capacity]].min.to_f / 
                      [festival.venue.capacity, historical_event[:capacity]].max
      scores << capacity_ratio * 0.3
    end

    # Duration similarity
    festival_duration = (festival.end_date - festival.start_date).to_i
    event_duration = historical_event[:duration] || 1
    duration_ratio = [festival_duration, event_duration].min.to_f / [festival_duration, event_duration].max
    scores << duration_ratio * 0.2

    # Category similarity (if available)
    if festival.category && historical_event[:category]
      scores << (festival.category == historical_event[:category] ? 1.0 : 0.3) * 0.3
    end

    # Season similarity
    festival_month = festival.start_date.month
    event_month = historical_event[:start_date]&.month || festival_month
    month_difference = [(festival_month - event_month).abs, 12 - (festival_month - event_month).abs].min
    season_score = 1.0 - (month_difference / 6.0)
    scores << season_score * 0.2

    scores.sum / scores.count
  end

  # Calculate weighted average attendance from similar events
  def weighted_average_attendance(similar_events)
    total_weight = 0
    weighted_sum = 0

    similar_events.each do |event|
      weight = event[:similarity_score] || 1.0
      attendance = event[:attendance] || 0
      
      weighted_sum += attendance * weight
      total_weight += weight
    end

    total_weight > 0 ? (weighted_sum / total_weight) : 0
  end

  # Estimate attendance from festival venue capacity
  def estimate_from_festival_capacity(festival)
    base_capacity = festival.venue&.capacity || 1000
    
    # Apply utilization rate based on festival type and pricing
    utilization_rate = calculate_utilization_rate(festival)
    
    (base_capacity * utilization_rate).round
  end

  # Calculate expected utilization rate
  def calculate_utilization_rate(festival)
    base_rate = 0.7 # 70% base utilization
    
    # Adjust for pricing
    if festival.respond_to?(:ticket_price)
      if festival.ticket_price == 0
        base_rate += 0.15 # Free events get higher attendance
      elsif festival.ticket_price > 5000
        base_rate -= 0.2 # Expensive events may have lower attendance
      end
    end

    # Adjust for festival duration
    duration_days = (festival.end_date - festival.start_date).to_i + 1
    if duration_days > 3
      base_rate -= 0.1 # Longer festivals may have lower daily attendance
    elsif duration_days == 1
      base_rate += 0.05 # Single day events often have higher concentration
    end

    [base_rate, 0.3].max # Minimum 30% utilization
  end

  # Calculate weather impact on attendance
  def calculate_weather_impact(weather_data)
    return 1.0 if weather_data.empty?

    impact_factor = 1.0
    
    # Temperature impact
    if weather_data[:temperature]
      temp = weather_data[:temperature]
      if temp < 5 || temp > 35
        impact_factor *= 0.8 # Extreme temperatures reduce attendance
      elsif temp.between?(15, 25)
        impact_factor *= 1.1 # Ideal temperature increases attendance
      end
    end

    # Precipitation impact
    if weather_data[:precipitation_probability]
      rain_prob = weather_data[:precipitation_probability]
      if rain_prob > 70
        impact_factor *= 0.6 # High rain probability significantly reduces attendance
      elsif rain_prob > 30
        impact_factor *= 0.85 # Medium rain probability moderately reduces attendance
      end
    end

    # Wind impact
    if weather_data[:wind_speed]
      wind = weather_data[:wind_speed]
      if wind > 20
        impact_factor *= 0.9 # Strong winds reduce attendance slightly
      end
    end

    impact_factor
  end

  # Calculate marketing impact on attendance
  def calculate_marketing_impact(festival)
    base_impact = 1.0
    
    # Social media presence
    if festival.respond_to?(:social_media_followers)
      followers = festival.social_media_followers || 0
      if followers > 10000
        base_impact += 0.2
      elsif followers > 1000
        base_impact += 0.1
      end
    end

    # Marketing budget (if available)
    if festival.respond_to?(:marketing_budget)
      budget = festival.marketing_budget || 0
      if budget > 100000
        base_impact += 0.15
      elsif budget > 50000
        base_impact += 0.1
      elsif budget > 10000
        base_impact += 0.05
      end
    end

    base_impact
  end

  # Calculate competition factor
  def calculate_competition_factor(festival)
    # Check for competing events in the same time period and area
    competing_events = Festival.where(
      start_date: (festival.start_date - 7.days)..(festival.end_date + 7.days)
    ).where.not(id: festival.id)

    return 1.0 if competing_events.empty?

    # Reduce attendance based on number and size of competing events
    competition_impact = 1.0 - (competing_events.count * 0.05)
    [competition_impact, 0.7].max # Minimum 70% attendance due to competition
  end

  # Calculate seasonal adjustment
  def calculate_seasonal_adjustment(festival)
    month = festival.start_date.month
    
    # Seasonal factors based on typical event attendance patterns
    seasonal_factors = {
      1 => 0.85,  # January - Lower attendance
      2 => 0.9,   # February
      3 => 1.0,   # March
      4 => 1.15,  # April - Spring events popular
      5 => 1.2,   # May - Peak season
      6 => 1.1,   # June
      7 => 1.0,   # July - Summer but potential vacation conflicts
      8 => 0.95,  # August - Vacation season
      9 => 1.1,   # September - Back to activities
      10 => 1.15, # October - Fall events popular
      11 => 1.0,  # November
      12 => 0.9   # December - Holiday conflicts
    }

    seasonal_factors[month] || 1.0
  end

  # Apply all prediction factors to base attendance
  def apply_prediction_factors(base_prediction, weather_adjustment:, marketing_impact:, competition_factor:, seasonal_adjustment:)
    base_prediction * weather_adjustment * marketing_impact * competition_factor * seasonal_adjustment
  end

  # Calculate confidence score for the prediction
  def calculate_confidence_score(festival, historical_data)
    confidence = 0.5 # Base confidence

    # Increase confidence with more historical data
    confidence += [historical_data.count * 0.1, 0.3].min

    # Increase confidence for festivals with more complete information
    if festival.venue&.capacity
      confidence += 0.1
    end

    if festival.respond_to?(:marketing_budget) && festival.marketing_budget
      confidence += 0.05
    end

    # Decrease confidence for very new festivals or unusual circumstances
    if festival.created_at > 30.days.ago
      confidence -= 0.1
    end

    [confidence, 0.95].min # Maximum 95% confidence
  end

  # Generate recommendations based on predicted attendance
  def generate_attendance_recommendations(predicted_attendance, festival)
    recommendations = []

    venue_capacity = festival.venue&.capacity || Float::INFINITY
    utilization_rate = predicted_attendance.to_f / venue_capacity

    if utilization_rate > 0.9
      recommendations << {
        type: 'capacity_warning',
        message: 'Predicted attendance is near venue capacity. Consider additional crowd control measures.',
        priority: 'high'
      }
    elsif utilization_rate < 0.3
      recommendations << {
        type: 'marketing_boost',
        message: 'Predicted attendance is low. Consider increasing marketing efforts.',
        priority: 'medium'
      }
    end

    if predicted_attendance > 5000
      recommendations << {
        type: 'logistics',
        message: 'Large attendance predicted. Ensure adequate parking, restrooms, and food vendors.',
        priority: 'high'
      }
    end

    recommendations
  end

  # Analyze venue space and constraints
  def analyze_venue_space(venue)
    return { success: false, error: 'Venue capacity not specified' } unless venue.capacity

    {
      success: true,
      total_area: venue.capacity * 2, # Rough estimate: 2 sq meters per person
      usable_area: venue.capacity * 1.5, # Account for pathways, facilities
      recommended_vendor_count: calculate_recommended_vendor_count(venue),
      layout_constraints: extract_venue_constraints(venue)
    }
  end

  # Calculate recommended number of vendors based on venue size
  def calculate_recommended_vendor_count(venue)
    # Base calculation: one vendor per 100-150 people capacity
    base_count = venue.capacity / 125
    
    # Adjust based on venue type
    if venue.respond_to?(:venue_type)
      multiplier = case venue.venue_type
                   when 'outdoor_park' then 1.2
                   when 'indoor_hall' then 0.8
                   when 'mixed' then 1.0
                   else 1.0
                   end
      base_count *= multiplier
    end

    [base_count.round, 5].max # Minimum 5 vendors
  end

  # Extract venue-specific constraints
  def extract_venue_constraints(venue)
    constraints = LAYOUT_OPTIMIZATION_CONSTRAINTS.dup

    # Adjust constraints based on venue characteristics
    if venue.respond_to?(:outdoor?) && venue.outdoor?
      constraints[:min_distance_between_vendors] = 4.0 # More space for outdoor events
      constraints[:emergency_access_width] = 5.0
    end

    constraints
  end

  # Categorize vendors by type and requirements
  def categorize_vendors(vendors)
    categories = {
      food_vendors: [],
      retail_vendors: [],
      service_vendors: [],
      entertainment: []
    }

    vendors.each do |vendor|
      category = determine_vendor_category(vendor)
      categories[category] << vendor
    end

    categories
  end

  # Determine vendor category based on business type
  def determine_vendor_category(vendor)
    business_type = vendor.business_type&.downcase || ''
    
    case business_type
    when /food|restaurant|catering|beverage/
      :food_vendors
    when /retail|shop|merchandise|craft/
      :retail_vendors
    when /service|consultation|repair/
      :service_vendors
    when /entertainment|music|performance/
      :entertainment
    else
      :retail_vendors # Default category
    end
  end

  # Generate optimal layout using constraint optimization
  def generate_optimal_layout(venue_analysis:, vendor_categories:, constraints:)
    layout = {
      vendor_positions: {},
      pathways: [],
      emergency_exits: [],
      facility_locations: {}
    }

    # Place vendors using optimization algorithm
    place_vendors_optimally(layout, venue_analysis, vendor_categories, constraints)
    
    # Add pathways and emergency access
    add_pathways_and_exits(layout, constraints)
    
    # Position facilities (restrooms, info booths, etc.)
    position_facilities(layout, venue_analysis)

    layout
  end

  # Place vendors in optimal positions
  def place_vendors_optimally(layout, venue_analysis, vendor_categories, constraints)
    total_vendors = vendor_categories.values.flatten.count
    grid_size = Math.sqrt(venue_analysis[:usable_area] / total_vendors)
    
    current_position = { x: 0, y: 0 }
    
    # Prioritize food vendors near entrance and high-traffic areas
    vendor_categories[:food_vendors].each_with_index do |vendor, index|
      position = calculate_vendor_position(current_position, grid_size, constraints)
      layout[:vendor_positions][vendor.id] = position
      current_position = advance_position(current_position, grid_size)
    end

    # Place other vendors
    [:retail_vendors, :service_vendors, :entertainment].each do |category|
      vendor_categories[category].each do |vendor|
        position = calculate_vendor_position(current_position, grid_size, constraints)
        layout[:vendor_positions][vendor.id] = position
        current_position = advance_position(current_position, grid_size)
      end
    end
  end

  # Calculate specific vendor position with constraints
  def calculate_vendor_position(current_position, grid_size, constraints)
    {
      x: current_position[:x],
      y: current_position[:y],
      width: grid_size * 0.8, # Leave space for pathways
      height: grid_size * 0.8,
      orientation: 'facing_pathway'
    }
  end

  # Advance to next position in grid
  def advance_position(current_position, grid_size)
    max_x = Math.sqrt(1000) * grid_size # Rough venue boundary
    
    if current_position[:x] + grid_size < max_x
      { x: current_position[:x] + grid_size, y: current_position[:y] }
    else
      { x: 0, y: current_position[:y] + grid_size }
    end
  end

  # Add pathways and emergency exits to layout
  def add_pathways_and_exits(layout, constraints)
    # Add main pathways
    layout[:pathways] = [
      { type: 'main', width: constraints[:emergency_access_width], coordinates: [[0, 0], [100, 0]] },
      { type: 'secondary', width: 3.0, coordinates: [[0, 0], [0, 100]] }
    ]

    # Add emergency exits
    layout[:emergency_exits] = [
      { location: 'north', width: constraints[:emergency_access_width] },
      { location: 'south', width: constraints[:emergency_access_width] }
    ]
  end

  # Position facilities like restrooms, info booths
  def position_facilities(layout, venue_analysis)
    layout[:facility_locations] = {
      restrooms: [
        { x: 20, y: 20, type: 'public' },
        { x: 80, y: 80, type: 'public' }
      ],
      info_booth: { x: 10, y: 10 },
      first_aid: { x: 50, y: 50 },
      security: { x: 5, y: 5 }
    }
  end

  # Validate layout meets safety and accessibility requirements
  def validate_layout(layout, constraints)
    errors = []

    # Check minimum distances between vendors
    vendor_positions = layout[:vendor_positions].values
    vendor_positions.each_with_index do |pos1, i|
      vendor_positions[(i+1)..-1].each do |pos2|
        distance = calculate_distance(pos1, pos2)
        if distance < constraints[:min_distance_between_vendors]
          errors << "Vendors too close: #{distance}m < #{constraints[:min_distance_between_vendors]}m"
        end
      end
    end

    # Check emergency access
    if layout[:emergency_exits].count < 2
      errors << "Insufficient emergency exits"
    end

    # Check pathway widths
    layout[:pathways].each do |pathway|
      if pathway[:width] < 2.0
        errors << "Pathway too narrow: #{pathway[:width]}m"
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # Calculate distance between two positions
  def calculate_distance(pos1, pos2)
    Math.sqrt((pos1[:x] - pos2[:x])**2 + (pos1[:y] - pos2[:y])**2)
  end

  # Calculate layout efficiency score
  def calculate_layout_efficiency(layout)
    # Score based on vendor spacing, pathway accessibility, facility placement
    base_score = 0.7
    
    # Bonus for well-distributed vendors
    if vendor_distribution_score(layout) > 0.8
      base_score += 0.15
    end

    # Bonus for efficient pathways
    if pathway_efficiency_score(layout) > 0.8
      base_score += 0.1
    end

    # Bonus for strategic facility placement
    if facility_placement_score(layout) > 0.8
      base_score += 0.05
    end

    [base_score, 1.0].min
  end

  # Calculate vendor distribution score
  def vendor_distribution_score(layout)
    # Measure how evenly vendors are distributed
    positions = layout[:vendor_positions].values
    return 0.5 if positions.count < 2

    total_distance = 0
    positions.each_with_index do |pos1, i|
      positions[(i+1)..-1].each do |pos2|
        total_distance += calculate_distance(pos1, pos2)
      end
    end

    # Normalize score based on optimal distribution
    avg_distance = total_distance / (positions.count * (positions.count - 1) / 2)
    [avg_distance / 20.0, 1.0].min # Assume optimal distance is around 20m
  end

  # Calculate pathway efficiency score
  def pathway_efficiency_score(layout)
    # Check if pathways provide good access to all vendors
    pathway_count = layout[:pathways].count
    vendor_count = layout[:vendor_positions].count
    
    # Basic score based on pathway to vendor ratio
    ratio_score = [pathway_count.to_f / vendor_count * 5, 1.0].min
    
    # Bonus for adequate pathway widths
    width_score = layout[:pathways].all? { |p| p[:width] >= 3.0 } ? 1.0 : 0.8
    
    (ratio_score + width_score) / 2
  end

  # Calculate facility placement score
  def facility_placement_score(layout)
    # Score based on strategic placement of facilities
    facilities = layout[:facility_locations]
    return 0.5 if facilities.empty?

    # Check if info booth is near entrance (low coordinates)
    info_score = facilities[:info_booth] && facilities[:info_booth][:x] < 20 ? 1.0 : 0.5
    
    # Check if restrooms are distributed
    restroom_score = if facilities[:restrooms]&.count&.>= 2
                       1.0
                     else
                       0.5
                     end

    (info_score + restroom_score) / 2
  end

  # Calculate crowd flow score
  def calculate_crowd_flow_score(layout)
    # Analyze how well the layout facilitates crowd movement
    pathway_coverage = calculate_pathway_coverage(layout)
    bottleneck_score = calculate_bottleneck_score(layout)
    accessibility_score = calculate_accessibility_score(layout)

    (pathway_coverage + bottleneck_score + accessibility_score) / 3
  end

  # Calculate pathway coverage
  def calculate_pathway_coverage(layout)
    # Check if pathways adequately cover the venue area
    total_pathway_length = layout[:pathways].sum { |p| calculate_pathway_length(p) }
    vendor_count = layout[:vendor_positions].count
    
    # Rough calculation: need about 10m of pathway per vendor
    coverage_ratio = total_pathway_length / (vendor_count * 10.0)
    [coverage_ratio, 1.0].min
  end

  # Calculate pathway length
  def calculate_pathway_length(pathway)
    coords = pathway[:coordinates]
    return 0 if coords.count < 2

    total_length = 0
    (0...(coords.count - 1)).each do |i|
      x1, y1 = coords[i]
      x2, y2 = coords[i + 1]
      total_length += Math.sqrt((x2 - x1)**2 + (y2 - y1)**2)
    end

    total_length
  end

  # Calculate bottleneck score
  def calculate_bottleneck_score(layout)
    # Check for potential bottlenecks in the layout
    min_pathway_width = layout[:pathways].map { |p| p[:width] }.min || 0
    
    if min_pathway_width >= 4.0
      1.0
    elsif min_pathway_width >= 3.0
      0.8
    elsif min_pathway_width >= 2.0
      0.6
    else
      0.4
    end
  end

  # Calculate accessibility score
  def calculate_accessibility_score(layout)
    # Check accessibility features
    score = 0.0
    
    # Emergency access
    emergency_exits = layout[:emergency_exits].count
    score += emergency_exits >= 2 ? 0.4 : 0.2

    # Pathway widths for accessibility
    accessible_pathways = layout[:pathways].count { |p| p[:width] >= 3.0 }
    total_pathways = layout[:pathways].count
    score += total_pathways > 0 ? (accessible_pathways.to_f / total_pathways) * 0.4 : 0.0

    # Facility accessibility
    if layout[:facility_locations][:restrooms]
      score += 0.2
    end

    score
  end

  # Generate layout recommendations
  def generate_layout_recommendations(layout)
    recommendations = []

    # Check vendor density
    vendor_count = layout[:vendor_positions].count
    if vendor_count > 50
      recommendations << {
        type: 'density_warning',
        message: 'High vendor density detected. Consider expanding venue or reducing vendor count.',
        priority: 'medium'
      }
    end

    # Check pathway adequacy
    min_width = layout[:pathways].map { |p| p[:width] }.min
    if min_width && min_width < 3.0
      recommendations << {
        type: 'pathway_width',
        message: 'Some pathways are narrow. Consider widening for better crowd flow.',
        priority: 'high'
      }
    end

    # Check emergency preparedness
    if layout[:emergency_exits].count < 3 && vendor_count > 30
      recommendations << {
        type: 'emergency_access',
        message: 'Large vendor count requires additional emergency exits.',
        priority: 'high'
      }
    end

    recommendations
  end

  # Generate alternative layouts
  def generate_alternative_layouts(venue_analysis, vendor_categories, count)
    alternatives = []
    
    count.times do |i|
      # Generate layout with different optimization priorities
      priority = i.even? ? 'crowd_flow' : 'vendor_revenue'
      alternative_layout = generate_layout_variant(venue_analysis, vendor_categories, priority)
      alternatives << {
        id: i + 1,
        optimization_priority: priority,
        layout: alternative_layout,
        efficiency_score: calculate_layout_efficiency(alternative_layout)
      }
    end

    alternatives
  end

  # Generate layout variant with different priorities
  def generate_layout_variant(venue_analysis, vendor_categories, priority)
    # This would implement different layout algorithms based on priority
    # For now, return a simplified variant
    base_layout = generate_optimal_layout(
      venue_analysis: venue_analysis,
      vendor_categories: vendor_categories,
      constraints: LAYOUT_OPTIMIZATION_CONSTRAINTS
    )

    # Modify layout based on priority
    case priority
    when 'crowd_flow'
      # Widen pathways, spread vendors more
      base_layout[:pathways].each { |p| p[:width] *= 1.2 }
    when 'vendor_revenue'
      # Place popular vendor types in prime locations
      # This would involve more sophisticated repositioning
    end

    base_layout
  end

  # Analyze festival profile for budget allocation
  def analyze_festival_profile(festival)
    profile = {
      size: categorize_festival_size(festival),
      type: festival.respond_to?(:category) ? festival.category : 'general',
      duration: (festival.end_date - festival.start_date).to_i + 1,
      outdoor: festival.venue&.respond_to?(:outdoor?) ? festival.venue.outdoor? : true,
      expected_attendance: festival.respond_to?(:expected_attendance) ? festival.expected_attendance : 1000
    }

    profile[:risk_level] = calculate_profile_risk_level(profile)
    profile
  end

  # Categorize festival size
  def categorize_festival_size(festival)
    capacity = festival.venue&.capacity || 1000
    
    case capacity
    when 0..500
      'small'
    when 501..2000
      'medium'
    when 2001..10000
      'large'
    else
      'mega'
    end
  end

  # Calculate risk level based on festival profile
  def calculate_profile_risk_level(profile)
    risk_score = 0
    
    risk_score += 1 if profile[:size] == 'mega'
    risk_score += 1 if profile[:duration] > 3
    risk_score += 1 if profile[:outdoor]
    risk_score += 1 if profile[:expected_attendance] > 5000

    case risk_score
    when 0..1
      'low'
    when 2..3
      'medium'
    else
      'high'
    end
  end

  # Calculate base budget allocation percentages
  def calculate_base_budget_allocation(festival_profile)
    # Base allocation percentages
    base_allocation = {
      venue_costs: 0.25,
      marketing_promotion: 0.15,
      security_safety: 0.12,
      infrastructure: 0.18,
      entertainment: 0.15,
      food_beverage: 0.05,
      logistics: 0.08,
      contingency: 0.02
    }

    # Adjust based on festival profile
    case festival_profile[:size]
    when 'small'
      base_allocation[:marketing_promotion] += 0.05
      base_allocation[:security_safety] -= 0.03
      base_allocation[:contingency] -= 0.02
    when 'mega'
      base_allocation[:security_safety] += 0.05
      base_allocation[:logistics] += 0.03
      base_allocation[:contingency] += 0.02
      base_allocation[:marketing_promotion] -= 0.05
      base_allocation[:entertainment] -= 0.05
    end

    # Adjust for outdoor events
    if festival_profile[:outdoor]
      base_allocation[:infrastructure] += 0.05
      base_allocation[:contingency] += 0.03
      base_allocation[:venue_costs] -= 0.05
      base_allocation[:entertainment] -= 0.03
    end

    # Adjust for high-risk events
    if festival_profile[:risk_level] == 'high'
      base_allocation[:security_safety] += 0.03
      base_allocation[:contingency] += 0.05
      base_allocation[:marketing_promotion] -= 0.05
      base_allocation[:entertainment] -= 0.03
    end

    normalize_allocation(base_allocation)
  end

  # Normalize allocation to ensure it totals 100%
  def normalize_allocation(allocation)
    total = allocation.values.sum
    return allocation if total == 1.0

    allocation.transform_values { |value| value / total }
  end

  # Calculate performance adjustments based on historical data
  def calculate_performance_adjustments(historical_performance)
    return {} if historical_performance.empty?

    adjustments = {}
    
    historical_performance.each do |performance|
      next unless performance[:category] && performance[:efficiency_score]

      category = performance[:category]
      efficiency = performance[:efficiency_score]
      
      # Adjust allocation based on historical efficiency
      if efficiency > 0.9
        adjustments[category] = (adjustments[category] || 0) + 0.02 # Increase well-performing categories
      elsif efficiency < 0.6
        adjustments[category] = (adjustments[category] || 0) - 0.03 # Decrease poor-performing categories
      end
    end

    adjustments
  end

  # Calculate risk adjustments for budget allocation
  def calculate_risk_adjustments(festival)
    adjustments = {}
    
    # Weather risk
    if festival.start_date.month.in?([11, 12, 1, 2]) # Winter months
      adjustments[:contingency] = 0.02
      adjustments[:infrastructure] = 0.01
    end

    # New festival risk
    if festival.created_at > 90.days.ago
      adjustments[:contingency] = (adjustments[:contingency] || 0) + 0.03
      adjustments[:marketing_promotion] = (adjustments[:marketing_promotion] || 0) + 0.02
    end

    adjustments
  end

  # Apply budget adjustments to base allocation
  def apply_budget_adjustments(base_allocation, performance_adjustments, risk_adjustments, total_budget)
    adjusted_allocation = base_allocation.dup
    
    # Apply performance adjustments
    performance_adjustments.each do |category, adjustment|
      if adjusted_allocation[category.to_sym]
        adjusted_allocation[category.to_sym] += adjustment
      end
    end

    # Apply risk adjustments
    risk_adjustments.each do |category, adjustment|
      if adjusted_allocation[category.to_sym]
        adjusted_allocation[category.to_sym] += adjustment
      end
    end

    # Normalize and convert to actual amounts
    normalized_allocation = normalize_allocation(adjusted_allocation)
    
    normalized_allocation.transform_values { |percentage| (percentage * total_budget).round(2) }
  end

  # Validate budget allocation
  def validate_budget_allocation(allocation, total_budget)
    errors = []
    
    # Check total equals budget
    allocation_total = allocation.values.sum
    difference = (allocation_total - total_budget).abs
    
    if difference > 1.0 # Allow for small rounding differences
      errors << "Allocation total (#{allocation_total}) doesn't match budget (#{total_budget})"
    end

    # Check for negative allocations
    negative_categories = allocation.select { |_, amount| amount < 0 }.keys
    if negative_categories.any?
      errors << "Negative allocations found: #{negative_categories.join(', ')}"
    end

    # Check minimum contingency
    contingency_percentage = allocation[:contingency] / total_budget
    if contingency_percentage < 0.02 # Minimum 2% contingency
      errors << "Contingency allocation too low (#{(contingency_percentage * 100).round(1)}%)"
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # Generate allocation rationale
  def generate_allocation_rationale(allocation, festival_profile)
    rationale = {}
    
    allocation.each do |category, amount|
      percentage = (amount / allocation.values.sum * 100).round(1)
      
      case category
      when :venue_costs
        rationale[category] = "#{percentage}% allocated for venue rental and facility costs"
      when :security_safety
        rationale[category] = "#{percentage}% for security and safety measures" +
                              (festival_profile[:risk_level] == 'high' ? " (increased due to high risk profile)" : "")
      when :marketing_promotion
        rationale[category] = "#{percentage}% for marketing and promotional activities" +
                              (festival_profile[:size] == 'small' ? " (increased for small festival visibility)" : "")
      when :contingency
        rationale[category] = "#{percentage}% contingency fund for unexpected expenses" +
                              (festival_profile[:outdoor] ? " (increased for outdoor event risks)" : "")
      else
        rationale[category] = "#{percentage}% allocated for #{category.to_s.humanize.downcase}"
      end
    end

    rationale
  end

  # Assess budget risks
  def assess_budget_risks(allocation, festival)
    risks = []
    total_budget = allocation.values.sum
    
    # Low contingency risk
    contingency_percentage = allocation[:contingency] / total_budget
    if contingency_percentage < 0.05
      risks << {
        type: 'low_contingency',
        severity: 'medium',
        description: "Contingency fund is #{(contingency_percentage * 100).round(1)}%, recommend minimum 5%"
      }
    end

    # High venue cost risk
    venue_percentage = allocation[:venue_costs] / total_budget
    if venue_percentage > 0.4
      risks << {
        type: 'high_venue_costs',
        severity: 'high',
        description: "Venue costs consume #{(venue_percentage * 100).round(1)}% of budget, limiting flexibility"
      }
    end

    # Marketing underfunding risk
    marketing_percentage = allocation[:marketing_promotion] / total_budget
    if marketing_percentage < 0.1 && festival.created_at > 90.days.ago
      risks << {
        type: 'underfunded_marketing',
        severity: 'medium',
        description: "New festival with only #{(marketing_percentage * 100).round(1)}% marketing budget may struggle with awareness"
      }
    end

    risks
  end

  # Identify optimization opportunities
  def identify_optimization_opportunities(allocation)
    opportunities = []
    total_budget = allocation.values.sum

    # Cost reduction opportunities
    logistics_percentage = allocation[:logistics] / total_budget
    if logistics_percentage > 0.12
      opportunities << {
        type: 'logistics_optimization',
        potential_savings: allocation[:logistics] * 0.15,
        description: "Logistics allocation high - consider vendor partnerships or bulk purchasing"
      }
    end

    # Revenue enhancement opportunities
    food_beverage_percentage = allocation[:food_beverage] / total_budget
    if food_beverage_percentage < 0.03
      opportunities << {
        type: 'revenue_enhancement',
        potential_revenue: total_budget * 0.02,
        description: "Low food/beverage allocation - consider revenue-sharing with vendors"
      }
    end

    # Efficiency improvements
    if allocation[:infrastructure] / total_budget > 0.25
      opportunities << {
        type: 'infrastructure_efficiency',
        potential_savings: allocation[:infrastructure] * 0.1,
        description: "High infrastructure costs - explore rental partnerships or reusable solutions"
      }
    end

    opportunities
  end

  # Generate contingency budget plan
  def generate_contingency_budget_plan(allocation)
    contingency_amount = allocation[:contingency]
    
    plan = {
      total_contingency: contingency_amount,
      allocation_breakdown: {
        emergency_response: contingency_amount * 0.4,
        weather_contingency: contingency_amount * 0.3,
        vendor_issues: contingency_amount * 0.15,
        equipment_failure: contingency_amount * 0.1,
        general_buffer: contingency_amount * 0.05
      },
      approval_thresholds: {
        immediate_use: contingency_amount * 0.1,
        manager_approval: contingency_amount * 0.3,
        executive_approval: contingency_amount * 0.5
      }
    }

    plan[:usage_guidelines] = [
      "Emergency response: Safety incidents, medical emergencies",
      "Weather contingency: Equipment protection, alternative arrangements",
      "Vendor issues: Last-minute cancellations, additional requirements",
      "Equipment failure: Backup equipment, emergency repairs",
      "General buffer: Unforeseen minor expenses"
    ]

    plan
  end

  # Assess specific risk category
  def assess_risk_category(festival, category)
    case category
    when 'weather'
      assess_weather_risk(festival)
    when 'safety'
      assess_safety_risk(festival)
    when 'security'
      assess_security_risk(festival)
    when 'financial'
      assess_financial_risk(festival)
    when 'operational'
      assess_operational_risk(festival)
    else
      { risk_score: 0.5, factors: [], mitigation_priority: 'medium' }
    end
  end

  # Assess weather-related risks
  def assess_weather_risk(festival)
    risk_score = 0.3 # Base risk

    # Seasonal risk
    month = festival.start_date.month
    if month.in?([12, 1, 2]) # Winter
      risk_score += 0.3
    elsif month.in?([6, 7, 8]) # Summer
      risk_score += 0.2
    end

    # Outdoor event risk
    if festival.venue&.respond_to?(:outdoor?) && festival.venue.outdoor?
      risk_score += 0.2
    end

    # Duration risk
    duration = (festival.end_date - festival.start_date).to_i + 1
    if duration > 3
      risk_score += 0.1
    end

    {
      risk_score: [risk_score, 1.0].min,
      factors: generate_weather_risk_factors(festival),
      mitigation_priority: risk_score > 0.7 ? 'high' : 'medium'
    }
  end

  # Generate weather risk factors
  def generate_weather_risk_factors(festival)
    factors = []
    
    if festival.venue&.respond_to?(:outdoor?) && festival.venue.outdoor?
      factors << "Outdoor venue susceptible to weather conditions"
    end

    month = festival.start_date.month
    if month.in?([12, 1, 2])
      factors << "Winter season increases risk of snow, ice, and cold temperatures"
    elsif month.in?([6, 7, 8])
      factors << "Summer season increases risk of rain, storms, and extreme heat"
    end

    duration = (festival.end_date - festival.start_date).to_i + 1
    if duration > 3
      factors << "Extended duration increases probability of adverse weather"
    end

    factors
  end

  # Assess safety-related risks
  def assess_safety_risk(festival)
    risk_score = 0.2 # Base risk

    # Attendance risk
    expected_attendance = festival.venue&.capacity || 1000
    if expected_attendance > 5000
      risk_score += 0.3
    elsif expected_attendance > 2000
      risk_score += 0.2
    end

    # Venue type risk
    if festival.venue&.respond_to?(:outdoor?) && festival.venue.outdoor?
      risk_score += 0.1
    end

    # Activity risk (if available)
    if festival.respond_to?(:activities) && festival.activities&.include?('alcohol')
      risk_score += 0.2
    end

    {
      risk_score: [risk_score, 1.0].min,
      factors: generate_safety_risk_factors(festival),
      mitigation_priority: risk_score > 0.6 ? 'high' : 'medium'
    }
  end

  # Generate safety risk factors
  def generate_safety_risk_factors(festival)
    factors = []
    
    expected_attendance = festival.venue&.capacity || 1000
    if expected_attendance > 5000
      factors << "Large crowd size increases safety management complexity"
    end

    if festival.venue&.respond_to?(:outdoor?) && festival.venue.outdoor?
      factors << "Outdoor venue requires additional safety considerations"
    end

    factors << "Standard safety risks include crowd control, emergency access, and incident response"
    
    factors
  end

  # Assess security-related risks
  def assess_security_risk(festival)
    risk_score = 0.25 # Base risk

    # Public event risk
    if festival.respond_to?(:public?) && festival.public?
      risk_score += 0.15
    end

    # Large attendance risk
    expected_attendance = festival.venue&.capacity || 1000
    if expected_attendance > 10000
      risk_score += 0.25
    elsif expected_attendance > 5000
      risk_score += 0.15
    end

    # High-profile event risk
    if festival.respond_to?(:media_attention) && festival.media_attention == 'high'
      risk_score += 0.2
    end

    {
      risk_score: [risk_score, 1.0].min,
      factors: generate_security_risk_factors(festival),
      mitigation_priority: risk_score > 0.6 ? 'high' : 'medium'
    }
  end

  # Generate security risk factors
  def generate_security_risk_factors(festival)
    factors = []
    
    if festival.respond_to?(:public?) && festival.public?
      factors << "Public event increases security screening requirements"
    end

    expected_attendance = festival.venue&.capacity || 1000
    if expected_attendance > 10000
      factors << "Very large attendance requires comprehensive security planning"
    elsif expected_attendance > 5000
      factors << "Large attendance requires enhanced security measures"
    end

    factors << "Standard security considerations include access control, bag checks, and crowd monitoring"
    
    factors
  end

  # Assess financial risks
  def assess_financial_risk(festival)
    risk_score = 0.3 # Base risk

    # New festival risk
    if festival.created_at > 90.days.ago
      risk_score += 0.2
    end

    # Large budget risk
    if festival.respond_to?(:budget) && festival.budget&.> 1000000
      risk_score += 0.2
    end

    # Ticket dependency risk
    if festival.respond_to?(:revenue_sources) && festival.revenue_sources&.include?('ticket_sales')
      risk_score += 0.1
    end

    {
      risk_score: [risk_score, 1.0].min,
      factors: generate_financial_risk_factors(festival),
      mitigation_priority: risk_score > 0.7 ? 'high' : 'medium'
    }
  end

  # Generate financial risk factors
  def generate_financial_risk_factors(festival)
    factors = []
    
    if festival.created_at > 90.days.ago
      factors << "New festival lacks historical performance data"
    end

    if festival.respond_to?(:budget) && festival.budget&.> 1000000
      factors << "Large budget increases financial exposure"
    end

    factors << "Standard financial risks include cost overruns, revenue shortfalls, and vendor payment issues"
    
    factors
  end

  # Assess operational risks
  def assess_operational_risk(festival)
    risk_score = 0.35 # Base risk

    # Complexity risk
    duration = (festival.end_date - festival.start_date).to_i + 1
    if duration > 5
      risk_score += 0.2
    elsif duration > 3
      risk_score += 0.1
    end

    # Multiple venue risk
    if festival.respond_to?(:venues) && festival.venues&.count&.> 1
      risk_score += 0.15
    end

    # Vendor complexity
    if festival.respond_to?(:vendor_applications_count) && festival.vendor_applications_count > 50
      risk_score += 0.15
    end

    {
      risk_score: [risk_score, 1.0].min,
      factors: generate_operational_risk_factors(festival),
      mitigation_priority: risk_score > 0.7 ? 'high' : 'medium'
    }
  end

  # Generate operational risk factors
  def generate_operational_risk_factors(festival)
    factors = []
    
    duration = (festival.end_date - festival.start_date).to_i + 1
    if duration > 5
      factors << "Extended duration increases operational complexity"
    elsif duration > 3
      factors << "Multi-day event requires sustained operational excellence"
    end

    if festival.respond_to?(:vendor_applications_count) && festival.vendor_applications_count > 50
      factors << "Large number of vendors increases coordination complexity"
    end

    factors << "Standard operational risks include logistics coordination, staff management, and schedule adherence"
    
    factors
  end

  # Calculate overall risk score
  def calculate_overall_risk_score(risk_assessment)
    weights = {
      weather: 0.2,
      safety: 0.25,
      security: 0.2,
      financial: 0.2,
      operational: 0.15
    }

    weighted_score = 0
    total_weight = 0

    risk_assessment.each do |category, assessment|
      weight = weights[category.to_sym] || 0.1
      weighted_score += assessment[:risk_score] * weight
      total_weight += weight
    end

    total_weight > 0 ? weighted_score / total_weight : 0.5
  end

  # Identify critical risks
  def identify_critical_risks(risk_assessment)
    critical_risks = []

    risk_assessment.each do |category, assessment|
      if assessment[:risk_score] > 0.7
        critical_risks << {
          category: category,
          risk_score: assessment[:risk_score],
          priority: assessment[:mitigation_priority],
          factors: assessment[:factors]
        }
      end
    end

    critical_risks.sort_by { |risk| -risk[:risk_score] }
  end

  # Generate mitigation strategies
  def generate_mitigation_strategies(risk_assessment)
    strategies = {}

    risk_assessment.each do |category, assessment|
      strategies[category] = case category
                            when 'weather'
                              generate_weather_mitigation_strategies(assessment)
                            when 'safety'
                              generate_safety_mitigation_strategies(assessment)
                            when 'security'
                              generate_security_mitigation_strategies(assessment)
                            when 'financial'
                              generate_financial_mitigation_strategies(assessment)
                            when 'operational'
                              generate_operational_mitigation_strategies(assessment)
                            else
                              []
                            end
    end

    strategies
  end

  # Generate weather mitigation strategies
  def generate_weather_mitigation_strategies(assessment)
    strategies = []
    
    if assessment[:risk_score] > 0.6
      strategies << {
        strategy: "Weather monitoring and contingency planning",
        implementation: "Establish 72-hour weather monitoring, prepare covered areas, have evacuation plan",
        cost_estimate: "Medium",
        effectiveness: "High"
      }
    end

    if assessment[:factors].any? { |f| f.include?('Outdoor') }
      strategies << {
        strategy: "Temporary shelter infrastructure",
        implementation: "Rent additional tents, covered walkways, and weather protection",
        cost_estimate: "High",
        effectiveness: "High"
      }
    end

    strategies << {
      strategy: "Weather-based decision protocols",
      implementation: "Define clear go/no-go criteria, communication plans, refund policies",
      cost_estimate: "Low",
      effectiveness: "Medium"
    }

    strategies
  end

  # Generate safety mitigation strategies
  def generate_safety_mitigation_strategies(assessment)
    strategies = []
    
    strategies << {
      strategy: "Comprehensive safety plan",
      implementation: "Develop detailed safety protocols, emergency response procedures, staff training",
      cost_estimate: "Medium",
      effectiveness: "High"
    }

    if assessment[:risk_score] > 0.6
      strategies << {
        strategy: "Enhanced medical and emergency services",
        implementation: "On-site medical staff, first aid stations, emergency vehicle access",
        cost_estimate: "High",
        effectiveness: "High"
      }
    end

    strategies << {
      strategy: "Crowd management systems",
      implementation: "Controlled entry/exit points, capacity monitoring, crowd flow design",
      cost_estimate: "Medium",
      effectiveness: "High"
    }

    strategies
  end

  # Generate security mitigation strategies
  def generate_security_mitigation_strategies(assessment)
    strategies = []
    
    if assessment[:risk_score] > 0.6
      strategies << {
        strategy: "Professional security services",
        implementation: "Hire licensed security personnel, implement access control, surveillance systems",
        cost_estimate: "High",
        effectiveness: "High"
      }
    end

    strategies << {
      strategy: "Access control and screening",
      implementation: "Bag checks, metal detectors, perimeter control, credential verification",
      cost_estimate: "Medium",
      effectiveness: "High"
    }

    strategies << {
      strategy: "Communication and coordination",
      implementation: "Security communication network, law enforcement liaison, incident reporting",
      cost_estimate: "Low",
      effectiveness: "Medium"
    }

    strategies
  end

  # Generate financial mitigation strategies
  def generate_financial_mitigation_strategies(assessment)
    strategies = []
    
    strategies << {
      strategy: "Diversified revenue streams",
      implementation: "Multiple funding sources, sponsorships, vendor fees, merchandise sales",
      cost_estimate: "Low",
      effectiveness: "High"
    }

    if assessment[:risk_score] > 0.6
      strategies << {
        strategy: "Financial reserves and insurance",
        implementation: "Maintain 15-20% contingency fund, event cancellation insurance, vendor guarantees",
        cost_estimate: "Medium",
        effectiveness: "High"
      }
    end

    strategies << {
      strategy: "Cost control and monitoring",
      implementation: "Regular budget reviews, approval processes, vendor contract management",
      cost_estimate: "Low",
      effectiveness: "Medium"
    }

    strategies
  end

  # Generate operational mitigation strategies
  def generate_operational_mitigation_strategies(assessment)
    strategies = []
    
    strategies << {
      strategy: "Detailed operational planning",
      implementation: "Comprehensive timelines, responsibility matrices, communication protocols",
      cost_estimate: "Low",
      effectiveness: "High"
    }

    if assessment[:risk_score] > 0.6
      strategies << {
        strategy: "Redundancy and backup systems",
        implementation: "Backup vendors, alternative suppliers, redundant equipment, cross-trained staff",
        cost_estimate: "Medium",
        effectiveness: "High"
      }
    end

    strategies << {
      strategy: "Regular rehearsals and testing",
      implementation: "Practice runs, system tests, staff drills, vendor coordination meetings",
      cost_estimate: "Low",
      effectiveness: "Medium"
    }

    strategies
  end

  # Generate monitoring recommendations
  def generate_monitoring_recommendations(risk_assessment)
    recommendations = []

    if risk_assessment['weather']&.dig(:risk_score)&.> 0.5
      recommendations << {
        area: 'Weather Monitoring',
        frequency: 'Continuous during event period',
        tools: 'Professional weather services, local observations, radar monitoring',
        triggers: 'Severe weather warnings, precipitation > 50%, winds > 25 mph'
      }
    end

    if risk_assessment['safety']&.dig(:risk_score)&.> 0.5
      recommendations << {
        area: 'Safety Monitoring',
        frequency: 'Continuous during event',
        tools: 'Incident reporting system, crowd density monitors, safety patrol reports',
        triggers: 'Any incidents, overcrowding, equipment failures'
      }
    end

    if risk_assessment['financial']&.dig(:risk_score)&.> 0.5
      recommendations << {
        area: 'Financial Monitoring',
        frequency: 'Daily during event preparation',
        tools: 'Budget tracking systems, vendor payment status, revenue monitoring',
        triggers: 'Budget variance > 10%, payment delays, revenue shortfalls'
      }
    end

    recommendations
  end

  # Generate risk contingency plans
  def generate_risk_contingency_plans(critical_risks)
    plans = {}

    critical_risks.each do |risk|
      plans[risk[:category]] = case risk[:category]
                               when 'weather'
                                 generate_weather_contingency_plan(risk)
                               when 'safety'
                                 generate_safety_contingency_plan(risk)
                               when 'security'
                                 generate_security_contingency_plan(risk)
                               when 'financial'
                                 generate_financial_contingency_plan(risk)
                               when 'operational'
                                 generate_operational_contingency_plan(risk)
                               else
                                 generate_generic_contingency_plan(risk)
                               end
    end

    plans
  end

  # Generate weather contingency plan
  def generate_weather_contingency_plan(risk)
    {
      trigger_conditions: [
        "Severe weather warning issued",
        "Precipitation probability > 70%",
        "Wind speeds > 30 mph",
        "Temperature < 0°C or > 40°C"
      ],
      immediate_actions: [
        "Activate weather monitoring protocol",
        "Notify all stakeholders",
        "Prepare sheltered areas",
        "Secure loose equipment and signage"
      ],
      escalation_procedures: [
        "30% capacity reduction if moderate conditions",
        "Postponement if severe conditions persist",
        "Full evacuation if dangerous conditions",
        "Communication to all attendees and vendors"
      ],
      resource_requirements: [
        "Additional tents and covered areas",
        "Weather monitoring equipment",
        "Emergency communication systems",
        "Transportation for evacuation if needed"
      ]
    }
  end

  # Generate safety contingency plan
  def generate_safety_contingency_plan(risk)
    {
      trigger_conditions: [
        "Any safety incident occurs",
        "Overcrowding in any area",
        "Equipment failure affecting safety",
        "Medical emergency"
      ],
      immediate_actions: [
        "Secure incident area",
        "Provide immediate assistance",
        "Contact emergency services if needed",
        "Document incident details"
      ],
      escalation_procedures: [
        "Area closure if safety risk persists",
        "Crowd redistribution protocols",
        "Event suspension if widespread risk",
        "Full evacuation if necessary"
      ],
      resource_requirements: [
        "On-site medical personnel",
        "First aid supplies and equipment",
        "Emergency communication systems",
        "Crowd control barriers and signage"
      ]
    }
  end

  # Generate security contingency plan
  def generate_security_contingency_plan(risk)
    {
      trigger_conditions: [
        "Security threat identified",
        "Unauthorized access attempt",
        "Disruptive behavior",
        "Suspicious activity reported"
      ],
      immediate_actions: [
        "Assess threat level",
        "Contain security situation",
        "Contact law enforcement if needed",
        "Protect other attendees"
      ],
      escalation_procedures: [
        "Increase security presence",
        "Implement additional screening",
        "Area lockdown if necessary",
        "Event cancellation for severe threats"
      ],
      resource_requirements: [
        "Professional security personnel",
        "Communication equipment",
        "Access control systems",
        "Law enforcement liaison"
      ]
    }
  end

  # Generate financial contingency plan
  def generate_financial_contingency_plan(risk)
    {
      trigger_conditions: [
        "Budget overrun > 10%",
        "Revenue shortfall > 15%",
        "Vendor payment default",
        "Unexpected major expense"
      ],
      immediate_actions: [
        "Assess financial impact",
        "Review remaining budget",
        "Identify cost reduction opportunities",
        "Communicate with stakeholders"
      ],
      escalation_procedures: [
        "Implement cost reduction measures",
        "Negotiate vendor payment terms",
        "Seek additional funding sources",
        "Scale back event if necessary"
      ],
      resource_requirements: [
        "Emergency fund access",
        "Financial management tools",
        "Vendor contract flexibility",
        "Alternative funding sources"
      ]
    }
  end

  # Generate operational contingency plan
  def generate_operational_contingency_plan(risk)
    {
      trigger_conditions: [
        "Key vendor cancellation",
        "Staff shortage",
        "Equipment failure",
        "Schedule disruption"
      ],
      immediate_actions: [
        "Assess operational impact",
        "Activate backup plans",
        "Reassign resources as needed",
        "Communicate changes to team"
      ],
      escalation_procedures: [
        "Implement alternative solutions",
        "Adjust event schedule",
        "Reduce scope if necessary",
        "Postpone if critical systems fail"
      ],
      resource_requirements: [
        "Backup vendor contacts",
        "Cross-trained staff",
        "Redundant equipment",
        "Flexible scheduling system"
      ]
    }
  end

  # Generate generic contingency plan
  def generate_generic_contingency_plan(risk)
    {
      trigger_conditions: ["Risk threshold exceeded", "Incident occurrence"],
      immediate_actions: ["Assess situation", "Implement response protocol"],
      escalation_procedures: ["Activate escalation chain", "Implement mitigation measures"],
      resource_requirements: ["Emergency response team", "Communication systems"]
    }
  end

  # Categorize risk level based on score
  def categorize_risk_level(overall_risk_score)
    case overall_risk_score
    when 0.0...0.3
      'low'
    when 0.3...0.6
      'medium'
    when 0.6...0.8
      'high'
    else
      'critical'
    end
  end

  # Generate error response
  def error_response(message)
    {
      success: false,
      error: message,
      timestamp: Time.current.iso8601
    }
  end
end