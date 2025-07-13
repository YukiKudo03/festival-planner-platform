class Api::V1::Integrations::CalendarController < Api::V1::BaseController
  before_action :set_calendar_integration, only: [:show, :update, :destroy, :sync, :export_events]

  # GET /api/v1/integrations/calendar
  def index
    integrations = current_user.calendar_integrations.includes(:festival)
    integrations = integrations.where(festival_id: params[:festival_id]) if params[:festival_id]
    integrations = integrations.where(provider: params[:provider]) if params[:provider]
    
    render json: {
      integrations: integrations.map { |integration| serialize_integration(integration) }
    }
  end

  # GET /api/v1/integrations/calendar/:id
  def show
    render json: {
      integration: serialize_integration_detailed(@integration)
    }
  end

  # POST /api/v1/integrations/calendar
  def create
    @integration = current_user.calendar_integrations.build(integration_params)
    
    if @integration.save
      # Test the connection
      test_result = test_calendar_connection(@integration)
      
      if test_result[:success]
        @integration.update(status: :connected)
        
        render json: {
          integration: serialize_integration_detailed(@integration),
          message: 'Calendar integration created successfully',
          connection_test: test_result
        }, status: :created
      else
        @integration.update(status: :error, last_sync_error: test_result[:message])
        
        render json: {
          integration: serialize_integration_detailed(@integration),
          message: 'Calendar integration created but connection failed',
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

  # PATCH /api/v1/integrations/calendar/:id
  def update
    if @integration.update(integration_params)
      render json: {
        integration: serialize_integration_detailed(@integration),
        message: 'Calendar integration updated successfully'
      }
    else
      render json: {
        errors: @integration.errors.full_messages,
        details: @integration.errors.details
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/integrations/calendar/:id
  def destroy
    @integration.destroy
    render json: {
      message: 'Calendar integration deleted successfully'
    }
  end

  # POST /api/v1/integrations/calendar/:id/sync
  def sync
    if @integration.sync_events!
      render json: {
        integration: serialize_integration_detailed(@integration),
        message: 'Calendar sync completed successfully',
        last_synced_at: @integration.last_synced_at
      }
    else
      render json: {
        integration: serialize_integration_detailed(@integration),
        message: 'Calendar sync failed',
        error: @integration.last_sync_error
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/integrations/calendar/:id/export_events
  def export_events
    events = @integration.export_festival_events
    
    case params[:format]
    when 'ical'
      ical_content = @integration.create_ical_feed
      
      render json: {
        format: 'ical',
        content: ical_content,
        download_url: ical_url(@integration),
        events_count: events.count
      }
    when 'json'
      render json: {
        format: 'json',
        events: events,
        events_count: events.count
      }
    else
      render json: {
        available_formats: ['ical', 'json'],
        events_count: events.count,
        preview: events.first(5)
      }
    end
  end

  # GET /api/v1/integrations/calendar/providers
  def providers
    render json: {
      providers: [
        {
          id: 'google',
          name: 'Google Calendar',
          description: 'Sync with Google Calendar',
          oauth_url: google_oauth_url,
          features: ['bidirectional_sync', 'recurring_events', 'reminders', 'shared_calendars']
        },
        {
          id: 'outlook',
          name: 'Microsoft Outlook',
          description: 'Sync with Outlook Calendar',
          oauth_url: outlook_oauth_url,
          features: ['bidirectional_sync', 'categories', 'importance_levels']
        },
        {
          id: 'ical',
          name: 'iCalendar (ICS)',
          description: 'Export to iCalendar format',
          oauth_url: nil,
          features: ['export_only', 'universal_compatibility']
        }
      ]
    }
  end

  # GET /api/v1/integrations/calendar/auth/google
  def google_auth
    redirect_to google_oauth_url
  end

  # GET /api/v1/integrations/calendar/auth/outlook
  def outlook_auth
    redirect_to outlook_oauth_url
  end

  # GET /api/v1/integrations/calendar/callback/google
  def google_callback
    if params[:code].present?
      begin
        # Exchange authorization code for access token
        auth_result = exchange_google_auth_code(params[:code])
        
        if auth_result[:success]
          # Create or update calendar integration
          integration = current_user.calendar_integrations.find_or_initialize_by(
            provider: 'google',
            calendar_id: 'primary'
          )
          
          integration.assign_attributes(
            name: 'Google Calendar',
            access_token: auth_result[:access_token],
            refresh_token: auth_result[:refresh_token],
            expires_at: Time.current + auth_result[:expires_in].seconds,
            client_id: ENV['GOOGLE_CLIENT_ID'],
            client_secret: ENV['GOOGLE_CLIENT_SECRET'],
            status: :connected,
            active: true
          )
          
          if params[:festival_id]
            integration.festival_id = params[:festival_id]
          end
          
          integration.save!
          
          render json: {
            integration: serialize_integration_detailed(integration),
            message: 'Google Calendar connected successfully'
          }
        else
          render json: {
            error: 'Failed to connect Google Calendar',
            details: auth_result[:error]
          }, status: :unprocessable_entity
        end
      rescue => error
        render json: {
          error: 'Authentication failed',
          details: error.message
        }, status: :unprocessable_entity
      end
    else
      render json: {
        error: 'Authorization code missing'
      }, status: :bad_request
    end
  end

  # GET /api/v1/integrations/calendar/callback/outlook
  def outlook_callback
    if params[:code].present?
      begin
        # Exchange authorization code for access token
        auth_result = exchange_outlook_auth_code(params[:code])
        
        if auth_result[:success]
          # Create or update calendar integration
          integration = current_user.calendar_integrations.find_or_initialize_by(
            provider: 'outlook',
            calendar_id: 'primary'
          )
          
          integration.assign_attributes(
            name: 'Outlook Calendar',
            access_token: auth_result[:access_token],
            refresh_token: auth_result[:refresh_token],
            expires_at: Time.current + auth_result[:expires_in].seconds,
            client_id: ENV['OUTLOOK_CLIENT_ID'],
            client_secret: ENV['OUTLOOK_CLIENT_SECRET'],
            status: :connected,
            active: true
          )
          
          if params[:festival_id]
            integration.festival_id = params[:festival_id]
          end
          
          integration.save!
          
          render json: {
            integration: serialize_integration_detailed(integration),
            message: 'Outlook Calendar connected successfully'
          }
        else
          render json: {
            error: 'Failed to connect Outlook Calendar',
            details: auth_result[:error]
          }, status: :unprocessable_entity
        end
      rescue => error
        render json: {
          error: 'Authentication failed',
          details: error.message
        }, status: :unprocessable_entity
      end
    else
      render json: {
        error: 'Authorization code missing'
      }, status: :bad_request
    end
  end

  # POST /api/v1/integrations/calendar/:id/test_connection
  def test_connection
    result = test_calendar_connection(@integration)
    
    if result[:success]
      @integration.update(status: :connected, last_sync_error: nil)
    else
      @integration.update(status: :error, last_sync_error: result[:message])
    end
    
    render json: {
      connection_test: result,
      integration: serialize_integration(@integration)
    }
  end

  # GET /api/v1/integrations/calendar/:id/calendars
  def calendars
    calendar_service = @integration.calendar_service
    result = calendar_service.fetch_calendars
    
    if result[:success]
      render json: {
        calendars: result[:calendars],
        current_calendar_id: @integration.calendar_id
      }
    else
      render json: {
        error: 'Failed to fetch calendars',
        details: result[:message]
      }, status: :unprocessable_entity
    end
  end

  private

  def set_calendar_integration
    @integration = current_user.calendar_integrations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Calendar integration not found' }, status: :not_found
  end

  def integration_params
    params.require(:calendar_integration).permit(
      :name, :provider, :calendar_id, :festival_id, :active,
      :sync_direction, :sync_interval, :access_token, :refresh_token,
      :client_id, :client_secret
    )
  end

  def serialize_integration(integration)
    {
      id: integration.id,
      name: integration.name,
      provider: integration.provider,
      calendar_id: integration.calendar_id,
      active: integration.active,
      status: integration.status,
      sync_direction: integration.sync_direction,
      last_synced_at: integration.last_synced_at&.iso8601,
      festival: integration.festival ? {
        id: integration.festival.id,
        name: integration.festival.name
      } : nil,
      created_at: integration.created_at.iso8601
    }
  end

  def serialize_integration_detailed(integration)
    serialize_integration(integration).merge(
      sync_interval: integration.sync_interval,
      last_sync_error: integration.last_sync_error,
      expires_at: integration.expires_at&.iso8601,
      sync_overdue: integration.sync_overdue?,
      token_expired: integration.token_expired?,
      updated_at: integration.updated_at.iso8601
    )
  end

  def test_calendar_connection(integration)
    calendar_service = integration.calendar_service
    calendar_service.test_connection
  rescue => error
    { success: false, message: error.message }
  end

  def google_oauth_url
    client_id = ENV['GOOGLE_CLIENT_ID']
    redirect_uri = api_v1_integrations_calendar_callback_google_url
    scope = 'https://www.googleapis.com/auth/calendar'
    
    "https://accounts.google.com/o/oauth2/auth?" +
    "client_id=#{client_id}&" +
    "redirect_uri=#{CGI.escape(redirect_uri)}&" +
    "scope=#{CGI.escape(scope)}&" +
    "response_type=code&" +
    "access_type=offline&" +
    "prompt=consent"
  end

  def outlook_oauth_url
    client_id = ENV['OUTLOOK_CLIENT_ID']
    redirect_uri = api_v1_integrations_calendar_callback_outlook_url
    scope = 'https://graph.microsoft.com/calendars.readwrite offline_access'
    
    "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?" +
    "client_id=#{client_id}&" +
    "redirect_uri=#{CGI.escape(redirect_uri)}&" +
    "scope=#{CGI.escape(scope)}&" +
    "response_type=code&" +
    "prompt=consent"
  end

  def exchange_google_auth_code(auth_code)
    begin
      auth_client = Google::Auth::UserRefreshCredentials.new(
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        redirect_uri: api_v1_integrations_calendar_callback_google_url
      )
      
      auth_client.code = auth_code
      auth_client.fetch_access_token!
      
      {
        success: true,
        access_token: auth_client.access_token,
        refresh_token: auth_client.refresh_token,
        expires_in: auth_client.expires_in || 3600
      }
    rescue => error
      {
        success: false,
        error: error.message
      }
    end
  end

  def exchange_outlook_auth_code(auth_code)
    begin
      oauth_client = OAuth2::Client.new(
        ENV['OUTLOOK_CLIENT_ID'],
        ENV['OUTLOOK_CLIENT_SECRET'],
        site: 'https://login.microsoftonline.com',
        token_url: '/common/oauth2/v2.0/token'
      )
      
      token = oauth_client.auth_code.get_token(
        auth_code,
        redirect_uri: api_v1_integrations_calendar_callback_outlook_url
      )
      
      {
        success: true,
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_in: token.expires_in || 3600
      }
    rescue => error
      {
        success: false,
        error: error.message
      }
    end
  end

  def ical_url(integration)
    # This would be a public URL for iCal feed
    api_v1_integrations_calendar_ical_url(integration.id, token: integration.ical_token)
  end
end