require 'net/http'
require 'json'
require 'cgi'

class GoogleMapsService
  BASE_URL = 'https://maps.googleapis.com/maps/api'
  
  def initialize(location_integration)
    @integration = location_integration
    @api_key = @integration.api_key
  end

  def geocode(address)
    begin
      url = "#{BASE_URL}/geocode/json"
      params = {
        address: address,
        key: @api_key,
        language: 'ja',
        region: 'jp'
      }

      response = make_request(url, params)
      
      if response['status'] == 'OK' && response['results'].any?
        result = response['results'].first
        location = result['geometry']['location']
        
        {
          success: true,
          latitude: location['lat'],
          longitude: location['lng'],
          formatted_address: result['formatted_address'],
          place_id: result['place_id'],
          address_components: parse_address_components(result['address_components']),
          viewport: result['geometry']['viewport']
        }
      else
        handle_geocoding_error(response['status'])
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def reverse_geocode(latitude, longitude)
    begin
      url = "#{BASE_URL}/geocode/json"
      params = {
        latlng: "#{latitude},#{longitude}",
        key: @api_key,
        language: 'ja',
        result_type: 'street_address|route|locality|political'
      }

      response = make_request(url, params)
      
      if response['status'] == 'OK' && response['results'].any?
        result = response['results'].first
        
        {
          success: true,
          address: result['formatted_address'],
          formatted_address: result['formatted_address'],
          address_components: parse_address_components(result['address_components']),
          place_id: result['place_id'],
          types: result['types']
        }
      else
        handle_geocoding_error(response['status'])
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def get_directions(origin, destination, options = {})
    begin
      url = "#{BASE_URL}/directions/json"
      params = {
        origin: format_location(origin),
        destination: format_location(destination),
        key: @api_key,
        language: 'ja',
        mode: options[:mode] || 'driving',
        avoid: options[:avoid],
        units: 'metric',
        departure_time: options[:departure_time],
        arrival_time: options[:arrival_time],
        traffic_model: options[:traffic_model] || 'best_guess'
      }.compact

      # Add waypoints if provided
      if options[:waypoints]
        waypoints = options[:waypoints].map { |wp| format_location(wp) }.join('|')
        params[:waypoints] = waypoints
      end

      response = make_request(url, params)
      
      if response['status'] == 'OK' && response['routes'].any?
        route = response['routes'].first
        leg = route['legs'].first
        
        {
          success: true,
          routes: response['routes'].map { |r| format_route(r) },
          distance: leg['distance'],
          duration: leg['duration'],
          duration_in_traffic: leg['duration_in_traffic'],
          polyline: route['overview_polyline']['points'],
          instructions: extract_instructions(route['legs']),
          bounds: route['bounds'],
          warnings: route['warnings'],
          copyrights: route['copyrights']
        }
      else
        handle_directions_error(response['status'])
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def search_nearby(latitude, longitude, query = nil, options = {})
    begin
      url = "#{BASE_URL}/place/nearbysearch/json"
      params = {
        location: "#{latitude},#{longitude}",
        key: @api_key,
        language: 'ja',
        radius: options[:radius] || 1000,
        type: options[:type],
        keyword: query,
        minprice: options[:min_price],
        maxprice: options[:max_price],
        opennow: options[:open_now],
        pagetoken: options[:page_token]
      }.compact

      response = make_request(url, params)
      
      if response['status'] == 'OK'
        {
          success: true,
          places: response['results'].map { |place| format_place(place) },
          next_page_token: response['next_page_token']
        }
      else
        handle_places_error(response['status'])
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def get_place_details(place_id)
    begin
      url = "#{BASE_URL}/place/details/json"
      params = {
        place_id: place_id,
        key: @api_key,
        language: 'ja',
        fields: 'name,rating,formatted_phone_number,formatted_address,geometry,opening_hours,photos,reviews,types,website,price_level'
      }

      response = make_request(url, params)
      
      if response['status'] == 'OK'
        place = response['result']
        
        {
          success: true,
          place: format_place_details(place),
          photos: format_photos(place['photos']),
          reviews: format_reviews(place['reviews']),
          opening_hours: format_opening_hours(place['opening_hours'])
        }
      else
        handle_places_error(response['status'])
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def create_static_map(latitude, longitude, options = {})
    begin
      url = "#{BASE_URL}/staticmap"
      params = {
        center: "#{latitude},#{longitude}",
        zoom: options[:zoom] || 15,
        size: "#{options[:width] || 800}x#{options[:height] || 600}",
        maptype: options[:map_type] || 'roadmap',
        key: @api_key,
        language: 'ja',
        region: 'jp'
      }

      # Add markers if provided
      if options[:markers] && options[:markers].any?
        markers_param = build_markers_param(options[:markers])
        params[:markers] = markers_param
      end

      # Add path if provided
      if options[:path]
        params[:path] = build_path_param(options[:path])
      end

      # Build URL
      query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
      map_url = "#{url}?#{query_string}"

      {
        success: true,
        map_url: map_url,
        width: options[:width] || 800,
        height: options[:height] || 600
      }
    rescue => error
      handle_request_error(error)
    end
  end

  def get_traffic_info(latitude, longitude, radius = 1000)
    # Google Maps doesn't have a direct traffic info API
    # We can use the roads API or directions API with traffic model
    begin
      # Get directions from the location to itself with traffic data
      url = "#{BASE_URL}/directions/json"
      params = {
        origin: "#{latitude},#{longitude}",
        destination: "#{latitude},#{longitude}",
        key: @api_key,
        departure_time: 'now',
        traffic_model: 'best_guess'
      }

      response = make_request(url, params)
      
      if response['status'] == 'OK'
        {
          success: true,
          traffic_conditions: 'normal', # Simplified - would need more complex logic
          incidents: [],
          construction: []
        }
      else
        { success: false, error: 'Traffic info not available' }
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def calculate_travel_time_matrix(origins, destinations, options = {})
    begin
      url = "#{BASE_URL}/distancematrix/json"
      params = {
        origins: origins.map { |o| format_location(o) }.join('|'),
        destinations: destinations.map { |d| format_location(d) }.join('|'),
        key: @api_key,
        language: 'ja',
        mode: options[:mode] || 'driving',
        units: 'metric',
        avoid: options[:avoid],
        departure_time: options[:departure_time] || 'now',
        traffic_model: options[:traffic_model] || 'best_guess'
      }.compact

      response = make_request(url, params)
      
      if response['status'] == 'OK'
        {
          success: true,
          matrix: format_distance_matrix(response),
          origin_addresses: response['origin_addresses'],
          destination_addresses: response['destination_addresses']
        }
      else
        handle_matrix_error(response['status'])
      end
    rescue => error
      handle_request_error(error)
    end
  end

  def test_connection
    begin
      # Simple test using geocoding API
      geocode_result = geocode('Tokyo, Japan')
      
      if geocode_result[:success]
        { success: true, message: 'Google Maps connection successful' }
      else
        { success: false, message: 'Google Maps API test failed' }
      end
    rescue => error
      { success: false, message: error.message }
    end
  end

  private

  def make_request(url, params)
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      raise "HTTP #{response.code}: #{response.message}"
    end
  end

  def format_location(location)
    case location
    when String
      location
    when Hash
      if location[:latitude] && location[:longitude]
        "#{location[:latitude]},#{location[:longitude]}"
      elsif location[:lat] && location[:lng]
        "#{location[:lat]},#{location[:lng]}"
      else
        location[:address] || location.to_s
      end
    when Array
      "#{location[0]},#{location[1]}"
    else
      location.to_s
    end
  end

  def parse_address_components(components)
    return [] unless components

    components.map do |component|
      {
        long_name: component['long_name'],
        short_name: component['short_name'],
        types: component['types']
      }
    end
  end

  def format_route(route)
    {
      summary: route['summary'],
      bounds: route['bounds'],
      legs: route['legs'].map { |leg| format_leg(leg) },
      overview_polyline: route['overview_polyline']['points'],
      warnings: route['warnings'],
      waypoint_order: route['waypoint_order']
    }
  end

  def format_leg(leg)
    {
      distance: leg['distance'],
      duration: leg['duration'],
      duration_in_traffic: leg['duration_in_traffic'],
      start_address: leg['start_address'],
      end_address: leg['end_address'],
      start_location: leg['start_location'],
      end_location: leg['end_location'],
      steps: leg['steps'].map { |step| format_step(step) }
    }
  end

  def format_step(step)
    {
      distance: step['distance'],
      duration: step['duration'],
      start_location: step['start_location'],
      end_location: step['end_location'],
      html_instructions: step['html_instructions'],
      travel_mode: step['travel_mode'],
      polyline: step['polyline']['points']
    }
  end

  def extract_instructions(legs)
    instructions = []
    
    legs.each do |leg|
      leg['steps'].each do |step|
        instructions << {
          instruction: step['html_instructions'],
          distance: step['distance'],
          duration: step['duration'],
          travel_mode: step['travel_mode']
        }
      end
    end
    
    instructions
  end

  def format_place(place)
    {
      place_id: place['place_id'],
      name: place['name'],
      vicinity: place['vicinity'],
      types: place['types'],
      rating: place['rating'],
      price_level: place['price_level'],
      location: place['geometry']['location'],
      opening_hours: place['opening_hours'],
      photos: place['photos']&.map { |photo| format_photo_reference(photo) },
      user_ratings_total: place['user_ratings_total']
    }
  end

  def format_place_details(place)
    {
      place_id: place['place_id'],
      name: place['name'],
      formatted_address: place['formatted_address'],
      formatted_phone_number: place['formatted_phone_number'],
      website: place['website'],
      types: place['types'],
      rating: place['rating'],
      price_level: place['price_level'],
      location: place['geometry']['location'],
      user_ratings_total: place['user_ratings_total']
    }
  end

  def format_photos(photos)
    return [] unless photos

    photos.map { |photo| format_photo_reference(photo) }
  end

  def format_photo_reference(photo)
    {
      photo_reference: photo['photo_reference'],
      width: photo['width'],
      height: photo['height'],
      html_attributions: photo['html_attributions'],
      photo_url: "#{BASE_URL}/place/photo?photoreference=#{photo['photo_reference']}&maxwidth=400&key=#{@api_key}"
    }
  end

  def format_reviews(reviews)
    return [] unless reviews

    reviews.map do |review|
      {
        author_name: review['author_name'],
        author_url: review['author_url'],
        language: review['language'],
        profile_photo_url: review['profile_photo_url'],
        rating: review['rating'],
        relative_time_description: review['relative_time_description'],
        text: review['text'],
        time: review['time']
      }
    end
  end

  def format_opening_hours(opening_hours)
    return nil unless opening_hours

    {
      open_now: opening_hours['open_now'],
      periods: opening_hours['periods'],
      weekday_text: opening_hours['weekday_text']
    }
  end

  def build_markers_param(markers)
    markers.map do |marker|
      parts = []
      parts << "color:#{marker[:color]}" if marker[:color]
      parts << "size:#{marker[:size]}" if marker[:size]
      parts << "label:#{marker[:label]}" if marker[:label]
      parts << "#{marker[:latitude]},#{marker[:longitude]}"
      parts.join('|')
    end.join('&markers=')
  end

  def build_path_param(path)
    parts = []
    parts << "color:#{path[:color]}" if path[:color]
    parts << "weight:#{path[:weight]}" if path[:weight]
    
    path[:points].each do |point|
      parts << "#{point[:latitude]},#{point[:longitude]}"
    end
    
    parts.join('|')
  end

  def format_distance_matrix(response)
    matrix = []
    
    response['rows'].each_with_index do |row, i|
      matrix[i] = []
      row['elements'].each_with_index do |element, j|
        matrix[i][j] = {
          distance: element['distance'],
          duration: element['duration'],
          duration_in_traffic: element['duration_in_traffic'],
          status: element['status']
        }
      end
    end
    
    matrix
  end

  def handle_geocoding_error(status)
    case status
    when 'ZERO_RESULTS'
      { success: false, error: 'No results found for the given address' }
    when 'OVER_DAILY_LIMIT'
      { success: false, error: 'Daily API quota exceeded' }
    when 'OVER_QUERY_LIMIT'
      { success: false, error: 'Query quota exceeded' }
    when 'REQUEST_DENIED'
      { success: false, error: 'Request denied - check API key' }
    when 'INVALID_REQUEST'
      { success: false, error: 'Invalid request parameters' }
    else
      { success: false, error: "Geocoding failed: #{status}" }
    end
  end

  def handle_directions_error(status)
    case status
    when 'NOT_FOUND'
      { success: false, error: 'At least one location could not be geocoded' }
    when 'ZERO_RESULTS'
      { success: false, error: 'No route could be found between the origin and destination' }
    when 'MAX_WAYPOINTS_EXCEEDED'
      { success: false, error: 'Too many waypoints provided' }
    when 'MAX_ROUTE_LENGTH_EXCEEDED'
      { success: false, error: 'Route is too long' }
    when 'INVALID_REQUEST'
      { success: false, error: 'Invalid directions request' }
    when 'OVER_DAILY_LIMIT'
      { success: false, error: 'Daily API quota exceeded' }
    when 'OVER_QUERY_LIMIT'
      { success: false, error: 'Query quota exceeded' }
    when 'REQUEST_DENIED'
      { success: false, error: 'Directions request denied' }
    else
      { success: false, error: "Directions failed: #{status}" }
    end
  end

  def handle_places_error(status)
    case status
    when 'ZERO_RESULTS'
      { success: false, error: 'No places found' }
    when 'OVER_QUERY_LIMIT'
      { success: false, error: 'Query quota exceeded' }
    when 'REQUEST_DENIED'
      { success: false, error: 'Places request denied' }
    when 'INVALID_REQUEST'
      { success: false, error: 'Invalid places request' }
    else
      { success: false, error: "Places search failed: #{status}" }
    end
  end

  def handle_matrix_error(status)
    case status
    when 'INVALID_REQUEST'
      { success: false, error: 'Invalid distance matrix request' }
    when 'MAX_ELEMENTS_EXCEEDED'
      { success: false, error: 'Too many elements in the matrix' }
    when 'MAX_DIMENSIONS_EXCEEDED'
      { success: false, error: 'Too many origins or destinations' }
    when 'OVER_DAILY_LIMIT'
      { success: false, error: 'Daily API quota exceeded' }
    when 'OVER_QUERY_LIMIT'
      { success: false, error: 'Query quota exceeded' }
    when 'REQUEST_DENIED'
      { success: false, error: 'Distance matrix request denied' }
    else
      { success: false, error: "Distance matrix failed: #{status}" }
    end
  end

  def handle_request_error(error)
    Rails.logger.error "Google Maps API request failed: #{error.message}"
    { success: false, error: "API request failed: #{error.message}" }
  end
end