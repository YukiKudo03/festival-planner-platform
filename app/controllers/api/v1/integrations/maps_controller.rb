class Api::V1::Integrations::MapsController < Api::V1::BaseController
  before_action :set_location_integration, only: [:show, :update, :destroy, :geocode, :reverse_geocode,
                                                   :directions, :nearby_places, :place_details, :static_map,
                                                   :traffic_info, :travel_time_matrix, :test_connection]

  # GET /api/v1/integrations/maps
  def index
    integrations = current_user.location_integrations.includes(:festival)
    integrations = integrations.where(festival_id: params[:festival_id]) if params[:festival_id]
    integrations = integrations.where(provider: params[:provider]) if params[:provider]
    integrations = integrations.where(active: true) if params[:active] == 'true'
    
    render json: {
      integrations: integrations.map { |integration| serialize_integration(integration) }
    }
  end

  # GET /api/v1/integrations/maps/:id
  def show
    render json: {
      integration: serialize_integration_detailed(@integration)
    }
  end

  # POST /api/v1/integrations/maps
  def create
    @integration = current_user.location_integrations.build(integration_params)
    
    if @integration.save
      # Test the connection
      test_result = test_location_connection(@integration)
      
      if test_result[:success]
        @integration.update(status: :connected)
        
        render json: {
          integration: serialize_integration_detailed(@integration),
          message: 'Location integration created successfully',
          connection_test: test_result
        }, status: :created
      else
        @integration.update(status: :error, last_error: test_result[:message])
        
        render json: {
          integration: serialize_integration_detailed(@integration),
          message: 'Location integration created but connection failed',
          connection_test: test_result
        }, status: :created
      end
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/integrations/maps/:id
  def update
    if @integration.update(integration_params)
      render json: {
        integration: serialize_integration_detailed(@integration),
        message: 'Location integration updated successfully'
      }
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/integrations/maps/:id
  def destroy
    @integration.destroy
    render json: {
      message: 'Location integration deleted successfully'
    }
  end

  # POST /api/v1/integrations/maps/:id/geocode
  def geocode
    unless @integration.supports_geocoding?
      return render json: {
        error: 'Geocoding is not supported for this provider'
      }, status: :unprocessable_entity
    end

    unless params[:address].present?
      return render json: {
        error: 'Address parameter is required'
      }, status: :bad_request
    end

    result = @integration.geocode_address(params[:address])

    if result[:success]
      # Log the geocoding event
      log_location_event('geocoding', {
        address: params[:address],
        latitude: result[:latitude],
        longitude: result[:longitude]
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Geocoding failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/maps/:id/reverse_geocode
  def reverse_geocode
    unless @integration.supports_geocoding?
      return render json: {
        error: 'Reverse geocoding is not supported for this provider'
      }, status: :unprocessable_entity
    end

    unless params[:latitude].present? && params[:longitude].present?
      return render json: {
        error: 'Latitude and longitude parameters are required'
      }, status: :bad_request
    end

    result = @integration.reverse_geocode(params[:latitude].to_f, params[:longitude].to_f)

    if result[:success]
      # Log the reverse geocoding event
      log_location_event('reverse_geocoding', {
        latitude: params[:latitude],
        longitude: params[:longitude],
        address: result[:address]
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Reverse geocoding failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/maps/:id/directions
  def directions
    unless @integration.supports_directions?
      return render json: {
        error: 'Directions are not supported for this provider'
      }, status: :unprocessable_entity
    end

    unless params[:origin].present? && params[:destination].present?
      return render json: {
        error: 'Origin and destination parameters are required'
      }, status: :bad_request
    end

    options = {
      mode: params[:mode],
      avoid: params[:avoid],
      waypoints: params[:waypoints],
      departure_time: params[:departure_time],
      arrival_time: params[:arrival_time],
      traffic_model: params[:traffic_model]
    }.compact

    result = @integration.get_directions(params[:origin], params[:destination], options)

    if result[:success]
      # Log the directions event
      log_location_event('directions', {
        origin: params[:origin],
        destination: params[:destination],
        mode: options[:mode],
        distance: result[:distance],
        duration: result[:duration]
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Directions request failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/maps/:id/nearby_places
  def nearby_places
    unless params[:latitude].present? && params[:longitude].present?
      return render json: {
        error: 'Latitude and longitude parameters are required'
      }, status: :bad_request
    end

    options = {
      radius: params[:radius]&.to_i,
      type: params[:type],
      min_price: params[:min_price]&.to_i,
      max_price: params[:max_price]&.to_i,
      open_now: params[:open_now] == 'true',
      page_token: params[:page_token]
    }.compact

    result = @integration.search_nearby_places(
      params[:latitude].to_f,
      params[:longitude].to_f,
      params[:query],
      options
    )

    if result[:success]
      # Log the places search event
      log_location_event('places_search', {
        latitude: params[:latitude],
        longitude: params[:longitude],
        query: params[:query],
        radius: options[:radius],
        results_count: result[:places]&.length
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Nearby places search failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/maps/:id/place_details/:place_id
  def place_details
    unless params[:place_id].present?
      return render json: {
        error: 'Place ID parameter is required'
      }, status: :bad_request
    end

    result = @integration.get_place_details(params[:place_id])

    if result[:success]
      # Log the place details event
      log_location_event('place_details', {
        place_id: params[:place_id],
        place_name: result[:place][:name]
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Place details request failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/maps/:id/static_map
  def static_map
    unless params[:latitude].present? && params[:longitude].present?
      return render json: {
        error: 'Latitude and longitude parameters are required'
      }, status: :bad_request
    end

    options = {
      zoom: params[:zoom]&.to_i,
      width: params[:width]&.to_i,
      height: params[:height]&.to_i,
      map_type: params[:map_type],
      markers: parse_markers_param(params[:markers]),
      path: parse_path_param(params[:path])
    }.compact

    result = @integration.create_static_map(
      params[:latitude].to_f,
      params[:longitude].to_f,
      options
    )

    if result[:success]
      # Log the static map event
      log_location_event('static_map', {
        latitude: params[:latitude],
        longitude: params[:longitude],
        zoom: options[:zoom],
        width: options[:width],
        height: options[:height]
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Static map creation failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/maps/:id/traffic_info
  def traffic_info
    unless @integration.supports_real_time_traffic?
      return render json: {
        error: 'Traffic information is not supported for this provider'
      }, status: :unprocessable_entity
    end

    unless params[:latitude].present? && params[:longitude].present?
      return render json: {
        error: 'Latitude and longitude parameters are required'
      }, status: :bad_request
    end

    radius = params[:radius]&.to_i || 1000
    result = @integration.get_traffic_info(
      params[:latitude].to_f,
      params[:longitude].to_f,
      radius
    )

    if result[:success]
      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Traffic information request failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/maps/:id/travel_time_matrix
  def travel_time_matrix
    unless params[:origins].present? && params[:destinations].present?
      return render json: {
        error: 'Origins and destinations parameters are required'
      }, status: :bad_request
    end

    origins = parse_locations_param(params[:origins])
    destinations = parse_locations_param(params[:destinations])

    options = {
      mode: params[:mode],
      avoid: params[:avoid],
      departure_time: params[:departure_time],
      traffic_model: params[:traffic_model]
    }.compact

    result = @integration.calculate_travel_time_matrix(origins, destinations, options)

    if result[:success]
      # Log the travel time matrix event
      log_location_event('travel_time_matrix', {
        origins_count: origins.length,
        destinations_count: destinations.length,
        mode: options[:mode]
      })

      render json: {
        result: result,
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Travel time matrix calculation failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/maps/:id/festival_map
  def festival_map
    unless @integration.festival
      return render json: {
        error: 'No festival associated with this integration'
      }, status: :unprocessable_entity
    end

    result = @integration.create_festival_map

    if result[:success]
      render json: {
        result: result,
        festival: {
          id: @integration.festival.id,
          name: @integration.festival.name,
          location: @integration.festival.location,
          latitude: @integration.festival.latitude,
          longitude: @integration.festival.longitude
        },
        integration: serialize_integration(@integration)
      }
    else
      render json: {
        error: 'Festival map creation failed',
        details: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/integrations/maps/:id/test_connection
  def test_connection
    result = test_location_connection(@integration)
    
    if result[:success]
      @integration.update(status: :connected, last_error: nil)
    else
      @integration.update(status: :error, last_error: result[:message])
    end
    
    render json: {
      connection_test: result,
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/maps/:id/analytics
  def analytics
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Time.current
    
    analytics = @integration.usage_analytics(start_date, end_date)
    
    render json: {
      analytics: analytics,
      period: {
        start_date: start_date.iso8601,
        end_date: end_date.iso8601
      },
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/maps/providers
  def providers
    render json: {
      providers: [
        {
          id: 'google_maps',
          name: 'Google Maps',
          description: 'Comprehensive mapping and location services',
          features: ['geocoding', 'directions', 'places', 'static_maps', 'street_view', 'traffic'],
          supported_countries: ['worldwide'],
          pricing_model: 'pay_per_use',
          setup_requirements: ['api_key']
        },
        {
          id: 'apple_maps',
          name: 'Apple Maps',
          description: 'Apple\'s mapping and location services',
          features: ['geocoding', 'directions', 'traffic'],
          supported_countries: ['worldwide'],
          pricing_model: 'free_tier_available',
          setup_requirements: ['api_key', 'team_id']
        },
        {
          id: 'mapbox',
          name: 'Mapbox',
          description: 'Customizable maps and location services',
          features: ['geocoding', 'directions', 'static_maps', 'custom_styling'],
          supported_countries: ['worldwide'],
          pricing_model: 'pay_per_use',
          setup_requirements: ['access_token']
        },
        {
          id: 'openstreetmap',
          name: 'OpenStreetMap',
          description: 'Open source mapping platform',
          features: ['geocoding', 'static_maps'],
          supported_countries: ['worldwide'],
          pricing_model: 'free',
          setup_requirements: ['none']
        }
      ]
    }
  end

  private

  def set_location_integration
    @integration = current_user.location_integrations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Location integration not found' }, status: :not_found
  end

  def integration_params
    params.require(:location_integration).permit(
      :name, :provider, :festival_id, :active, :api_key, :api_secret,
      :map_style, :default_zoom_level, :map_width, :map_height
    )
  end

  def serialize_integration(integration)
    {
      id: integration.id,
      name: integration.name,
      provider: integration.provider,
      active: integration.active,
      status: integration.status,
      map_style: integration.map_style,
      supports_geocoding: integration.supports_geocoding?,
      supports_directions: integration.supports_directions?,
      supports_street_view: integration.supports_street_view?,
      supports_real_time_traffic: integration.supports_real_time_traffic?,
      festival: integration.festival ? {
        id: integration.festival.id,
        name: integration.festival.name,
        location: integration.festival.location
      } : nil,
      created_at: integration.created_at.iso8601
    }
  end

  def serialize_integration_detailed(integration)
    serialize_integration(integration).merge(
      default_zoom_level: integration.default_zoom_level,
      map_width: integration.map_width,
      map_height: integration.map_height,
      last_map_url: integration.last_map_url,
      last_generated_at: integration.last_generated_at&.iso8601,
      last_error: integration.last_error,
      updated_at: integration.updated_at.iso8601
    )
  end

  def test_location_connection(integration)
    integration.test_connection
  rescue => error
    { success: false, message: error.message }
  end

  def log_location_event(event_type, data)
    @integration.location_events.create!(
      event_type: event_type,
      event_data: data,
      success: true,
      user: current_user
    )
  rescue => error
    Rails.logger.error "Failed to log location event: #{error.message}"
  end

  def parse_markers_param(markers_param)
    return nil unless markers_param

    if markers_param.is_a?(String)
      JSON.parse(markers_param)
    else
      markers_param
    end
  rescue JSON::ParserError
    nil
  end

  def parse_path_param(path_param)
    return nil unless path_param

    if path_param.is_a?(String)
      JSON.parse(path_param)
    else
      path_param
    end
  rescue JSON::ParserError
    nil
  end

  def parse_locations_param(locations_param)
    if locations_param.is_a?(String)
      locations_param.split('|')
    elsif locations_param.is_a?(Array)
      locations_param
    else
      []
    end
  end
end