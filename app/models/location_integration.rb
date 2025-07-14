class LocationIntegration < ApplicationRecord
  belongs_to :user
  belongs_to :festival, optional: true
  has_many :location_markers, dependent: :destroy
  has_many :location_events, dependent: :destroy

  validates :provider, presence: true, inclusion: { in: %w[google_maps apple_maps mapbox openstreetmap] }
  validates :name, presence: true
  validates :api_key, presence: true

  encrypts :api_key
  encrypts :api_secret

  scope :active, -> { where(active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }

  enum status: {
    connected: 0,
    disconnected: 1,
    error: 2,
    pending_verification: 3
  }

  enum map_style: {
    standard: 0,
    satellite: 1,
    hybrid: 2,
    terrain: 3,
    dark: 4,
    light: 5
  }

  before_create :set_defaults
  after_update :update_map_configuration, if: :saved_change_to_active?

  def google_maps?
    provider == "google_maps"
  end

  def apple_maps?
    provider == "apple_maps"
  end

  def mapbox?
    provider == "mapbox"
  end

  def openstreetmap?
    provider == "openstreetmap"
  end

  def maps_enabled?
    active? && connected? && api_key.present?
  end

  def supports_geocoding?
    %w[google_maps mapbox].include?(provider)
  end

  def supports_directions?
    %w[google_maps apple_maps mapbox].include?(provider)
  end

  def supports_street_view?
    %w[google_maps].include?(provider)
  end

  def supports_real_time_traffic?
    %w[google_maps apple_maps].include?(provider)
  end

  def location_service
    @location_service ||= case provider
    when "google_maps"
                           GoogleMapsService.new(self)
    when "apple_maps"
                           AppleMapsService.new(self)
    when "mapbox"
                           MapboxService.new(self)
    when "openstreetmap"
                           OpenStreetMapService.new(self)
    end
  end

  def geocode_address(address)
    return { success: false, error: "Geocoding not supported" } unless supports_geocoding?

    begin
      result = location_service.geocode(address)

      if result[:success]
        {
          success: true,
          latitude: result[:latitude],
          longitude: result[:longitude],
          formatted_address: result[:formatted_address],
          place_id: result[:place_id],
          address_components: result[:address_components]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Geocoding failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def reverse_geocode(latitude, longitude)
    return { success: false, error: "Reverse geocoding not supported" } unless supports_geocoding?

    begin
      result = location_service.reverse_geocode(latitude, longitude)

      if result[:success]
        {
          success: true,
          address: result[:address],
          formatted_address: result[:formatted_address],
          address_components: result[:address_components],
          place_id: result[:place_id]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Reverse geocoding failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def get_directions(origin, destination, options = {})
    return { success: false, error: "Directions not supported" } unless supports_directions?

    begin
      result = location_service.get_directions(origin, destination, options)

      if result[:success]
        {
          success: true,
          routes: result[:routes],
          distance: result[:distance],
          duration: result[:duration],
          polyline: result[:polyline],
          instructions: result[:instructions]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Directions request failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def search_nearby_places(latitude, longitude, query = nil, options = {})
    begin
      result = location_service.search_nearby(latitude, longitude, query, options)

      if result[:success]
        {
          success: true,
          places: result[:places],
          next_page_token: result[:next_page_token]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Nearby places search failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def get_place_details(place_id)
    begin
      result = location_service.get_place_details(place_id)

      if result[:success]
        {
          success: true,
          place: result[:place],
          photos: result[:photos],
          reviews: result[:reviews],
          opening_hours: result[:opening_hours]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Place details request failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def create_static_map(latitude, longitude, options = {})
    begin
      result = location_service.create_static_map(latitude, longitude, options)

      if result[:success]
        {
          success: true,
          map_url: result[:map_url],
          width: result[:width],
          height: result[:height]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Static map creation failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def create_festival_map
    return { success: false, error: "No festival associated" } unless festival

    begin
      # Geocode festival location if not already done
      if festival.latitude.blank? || festival.longitude.blank?
        geocode_result = geocode_address(festival.location)

        if geocode_result[:success]
          festival.update!(
            latitude: geocode_result[:latitude],
            longitude: geocode_result[:longitude]
          )
        else
          return { success: false, error: "Failed to geocode festival location" }
        end
      end

      # Create markers for festival and related locations
      markers = build_festival_markers

      # Create map with festival location and markers
      map_options = {
        zoom: default_zoom_level,
        map_type: map_style,
        markers: markers,
        width: map_width || 800,
        height: map_height || 600
      }

      static_map_result = create_static_map(festival.latitude, festival.longitude, map_options)

      if static_map_result[:success]
        # Save map configuration
        update!(
          last_map_url: static_map_result[:map_url],
          last_generated_at: Time.current
        )

        static_map_result
      else
        static_map_result
      end
    rescue => error
      Rails.logger.error "Festival map creation failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def get_traffic_info(latitude, longitude, radius = 1000)
    return { success: false, error: "Traffic info not supported" } unless supports_real_time_traffic?

    begin
      result = location_service.get_traffic_info(latitude, longitude, radius)

      if result[:success]
        {
          success: true,
          traffic_conditions: result[:traffic_conditions],
          incidents: result[:incidents],
          construction: result[:construction]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Traffic info request failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def calculate_travel_time_matrix(origins, destinations, options = {})
    begin
      result = location_service.calculate_travel_time_matrix(origins, destinations, options)

      if result[:success]
        {
          success: true,
          matrix: result[:matrix],
          origin_addresses: result[:origin_addresses],
          destination_addresses: result[:destination_addresses]
        }
      else
        result
      end
    rescue => error
      Rails.logger.error "Travel time matrix calculation failed for integration #{id}: #{error.message}"
      { success: false, error: error.message }
    end
  end

  def test_connection
    location_service.test_connection
  rescue => error
    { success: false, message: error.message }
  end

  def usage_analytics(start_date = 30.days.ago, end_date = Time.current)
    {
      total_geocoding_requests: geocoding_request_count(start_date, end_date),
      total_directions_requests: directions_request_count(start_date, end_date),
      total_places_searches: places_search_count(start_date, end_date),
      total_static_maps: static_map_count(start_date, end_date),
      most_searched_locations: most_searched_locations(start_date, end_date),
      peak_usage_hours: peak_usage_hours(start_date, end_date),
      error_rate: error_rate(start_date, end_date)
    }
  end

  private

  def set_defaults
    self.active ||= true
    self.status ||= :connected
    self.map_style ||= :standard
    self.default_zoom_level ||= 15
    self.map_width ||= 800
    self.map_height ||= 600
  end

  def update_map_configuration
    return unless active?

    LocationMapUpdateJob.perform_later(id)
  end

  def build_festival_markers
    markers = []

    # Main festival marker
    if festival.latitude && festival.longitude
      markers << {
        latitude: festival.latitude,
        longitude: festival.longitude,
        title: festival.name,
        description: festival.description,
        icon: "festival",
        color: "red",
        size: "large"
      }
    end

    # Task-based markers (venues, setup locations, etc.)
    festival.tasks.where.not(location: nil).find_each do |task|
      if task.latitude && task.longitude
        markers << {
          latitude: task.latitude,
          longitude: task.longitude,
          title: task.title,
          description: task.description,
          icon: task_icon(task),
          color: task_color(task),
          size: "medium"
        }
      end
    end

    # Custom location markers
    location_markers.active.find_each do |marker|
      markers << {
        latitude: marker.latitude,
        longitude: marker.longitude,
        title: marker.title,
        description: marker.description,
        icon: marker.icon_type,
        color: marker.color,
        size: marker.size
      }
    end

    markers
  end

  def task_icon(task)
    case task.category&.downcase
    when "setup"
      "construction"
    when "security"
      "security"
    when "food"
      "restaurant"
    when "entertainment"
      "music"
    when "cleanup"
      "cleanup"
    else
      "task"
    end
  end

  def task_color(task)
    case task.status
    when "completed"
      "green"
    when "in_progress"
      "yellow"
    when "pending"
      "blue"
    else
      "gray"
    end
  end

  def geocoding_request_count(start_date, end_date)
    # This would be tracked in a separate analytics table
    location_events.where(
      event_type: "geocoding",
      created_at: start_date..end_date
    ).count
  end

  def directions_request_count(start_date, end_date)
    location_events.where(
      event_type: "directions",
      created_at: start_date..end_date
    ).count
  end

  def places_search_count(start_date, end_date)
    location_events.where(
      event_type: "places_search",
      created_at: start_date..end_date
    ).count
  end

  def static_map_count(start_date, end_date)
    location_events.where(
      event_type: "static_map",
      created_at: start_date..end_date
    ).count
  end

  def most_searched_locations(start_date, end_date)
    location_events.where(
      created_at: start_date..end_date
    ).group(:search_query)
     .order(count: :desc)
     .limit(10)
     .count
  end

  def peak_usage_hours(start_date, end_date)
    location_events.where(
      created_at: start_date..end_date
    ).group_by_hour(:created_at)
     .count
     .sort_by { |hour, count| -count }
     .first(5)
     .to_h
  end

  def error_rate(start_date, end_date)
    total_requests = location_events.where(created_at: start_date..end_date).count
    error_requests = location_events.where(
      created_at: start_date..end_date,
      success: false
    ).count

    return 0 if total_requests.zero?

    (error_requests.to_f / total_requests * 100).round(2)
  end
end
