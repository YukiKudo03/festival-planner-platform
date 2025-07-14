# frozen_string_literal: true

# API controller for municipal authority operations
# Handles government authority integration and data management
class Api::V1::MunicipalAuthoritiesController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_municipal_authority, only: [ :show, :update, :destroy, :sync, :test_connection, :contacts ]
  before_action :authorize_admin!, except: [ :index, :show, :contacts ]

  # GET /api/v1/municipal_authorities
  def index
    @authorities = MunicipalAuthority.includes(:municipal_contacts, :subsidy_programs)

    # Apply filters
    @authorities = @authorities.by_prefecture(params[:prefecture]) if params[:prefecture].present?
    @authorities = @authorities.by_authority_type(params[:authority_type]) if params[:authority_type].present?
    @authorities = @authorities.active if params[:active_only] == "true"
    @authorities = @authorities.in_jurisdiction(params[:area]) if params[:area].present?

    # Pagination
    page = params[:page] || 1
    per_page = [ params[:per_page]&.to_i || 20, 100 ].min
    @authorities = @authorities.page(page).per(per_page)

    render json: {
      success: true,
      data: {
        authorities: @authorities.map { |authority| authority_summary(authority) },
        pagination: pagination_meta(@authorities),
        filters: {
          prefectures: MunicipalAuthority::PREFECTURES,
          authority_types: MunicipalAuthority::AUTHORITY_TYPES
        }
      }
    }
  end

  # GET /api/v1/municipal_authorities/:id
  def show
    render json: {
      success: true,
      data: {
        authority: detailed_authority_data(@authority)
      }
    }
  end

  # POST /api/v1/municipal_authorities
  def create
    @authority = MunicipalAuthority.new(authority_params)

    if @authority.save
      render json: {
        success: true,
        data: {
          authority: detailed_authority_data(@authority)
        },
        message: "Municipal authority created successfully"
      }, status: :created
    else
      render json: {
        success: false,
        errors: @authority.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/municipal_authorities/:id
  def update
    if @authority.update(authority_params)
      render json: {
        success: true,
        data: {
          authority: detailed_authority_data(@authority)
        },
        message: "Municipal authority updated successfully"
      }
    else
      render json: {
        success: false,
        errors: @authority.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/municipal_authorities/:id
  def destroy
    if @authority.destroy
      render json: {
        success: true,
        message: "Municipal authority deleted successfully"
      }
    else
      render json: {
        success: false,
        errors: @authority.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/municipal_authorities/:id/sync
  def sync
    service = MunicipalIntegrationService.new(@authority)

    # Sync authority data
    authority_result = service.sync_authority_data
    contacts_result = service.sync_contact_information
    programs_result = service.sync_subsidy_programs

    if authority_result[:success] && contacts_result[:success] && programs_result[:success]
      render json: {
        success: true,
        data: {
          authority_sync: authority_result,
          contacts_sync: contacts_result,
          programs_sync: programs_result,
          last_sync: @authority.reload.last_api_sync_at
        },
        message: "Municipal authority data synchronized successfully"
      }
    else
      render json: {
        success: false,
        errors: [
          authority_result[:error],
          contacts_result[:error],
          programs_result[:error]
        ].compact
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/municipal_authorities/:id/test_connection
  def test_connection
    service = MunicipalIntegrationService.new(@authority)
    result = service.test_connection

    if result[:success]
      render json: {
        success: true,
        data: {
          connection_status: "Connected",
          api_response: result[:data],
          tested_at: Time.current
        },
        message: "Connection test successful"
      }
    else
      render json: {
        success: false,
        data: {
          connection_status: "Failed",
          error: result[:error],
          tested_at: Time.current
        },
        message: "Connection test failed"
      }, status: :service_unavailable
    end
  end

  # GET /api/v1/municipal_authorities/:id/contacts
  def contacts
    contacts = @authority.municipal_contacts.active.includes(:municipal_authority)

    # Filter by contact type if specified
    contacts = contacts.by_contact_type(params[:contact_type]) if params[:contact_type].present?

    render json: {
      success: true,
      data: {
        contacts: contacts.map(&:api_summary),
        authority: {
          id: @authority.id,
          name: @authority.name,
          currently_open: @authority.currently_open?
        }
      }
    }
  end

  # GET /api/v1/municipal_authorities/search
  def search
    query = params[:q]&.strip
    area = params[:area]&.strip
    permit_type = params[:permit_type]

    authorities = MunicipalAuthority.active

    if query.present?
      authorities = authorities.where(
        "name ILIKE ? OR city ILIKE ? OR prefecture ILIKE ?",
        "%#{query}%", "%#{query}%", "%#{query}%"
      )
    end

    if area.present?
      authorities = authorities.for_area(area)
    end

    if permit_type.present?
      authorities = authorities.handling_permit_type(permit_type)
    end

    authorities = authorities.limit(50) # Limit search results

    render json: {
      success: true,
      data: {
        authorities: authorities.map { |authority| authority_summary(authority) },
        query: query,
        area: area,
        permit_type: permit_type
      }
    }
  end

  # GET /api/v1/municipal_authorities/for_festival
  def for_festival
    festival = Festival.find(params[:festival_id])
    venue_address = festival.venue&.address || params[:venue_address]

    return render_error("Venue address is required", :bad_request) unless venue_address.present?

    # Find authorities with jurisdiction
    authorities = MunicipalAuthority.for_area(venue_address).active

    # Get required permits for each authority
    authorities_with_permits = authorities.map do |authority|
      required_permits = authority.required_permits_for(
        festival.category || "general",
        festival.expected_attendance || 0
      )

      {
        authority: authority_summary(authority),
        required_permits: required_permits,
        subsidy_programs: authority.available_subsidies(
          festival_type: festival.category,
          estimated_budget: festival.total_budget
        ).map { |program| subsidy_program_summary(program) }
      }
    end

    render json: {
      success: true,
      data: {
        festival: {
          id: festival.id,
          name: festival.name,
          category: festival.category,
          expected_attendance: festival.expected_attendance
        },
        venue_address: venue_address,
        authorities: authorities_with_permits
      }
    }
  end

  # GET /api/v1/municipal_authorities/statistics
  def statistics
    stats = {
      total_authorities: MunicipalAuthority.count,
      active_authorities: MunicipalAuthority.active.count,
      by_prefecture: MunicipalAuthority.group(:prefecture).count,
      by_authority_type: MunicipalAuthority.group(:authority_type).count,
      with_api_integration: MunicipalAuthority.where.not(api_endpoint: nil).count,
      permit_applications: {
        total: PermitApplication.count,
        pending: PermitApplication.pending.count,
        approved: PermitApplication.approved.count,
        this_month: PermitApplication.where(created_at: 1.month.ago..Time.current).count
      },
      subsidy_programs: {
        total: SubsidyProgram.count,
        active: SubsidyProgram.active.count,
        accepting_applications: SubsidyProgram.accepting_applications.count,
        total_budget: SubsidyProgram.sum(:total_budget)
      }
    }

    render json: {
      success: true,
      data: stats
    }
  end

  private

  def set_municipal_authority
    @authority = MunicipalAuthority.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Municipal authority not found")
  end

  def authority_params
    params.require(:municipal_authority).permit(
      :name, :prefecture, :city, :authority_type, :contact_email, :phone_number,
      :address, :jurisdiction_area, :status, :api_endpoint, :api_key,
      :minimum_advance_days, :auto_assign_reviews,
      :working_hours_monday, :working_hours_tuesday, :working_hours_wednesday,
      :working_hours_thursday, :working_hours_friday, :working_hours_saturday,
      :working_hours_sunday
    )
  end

  def authority_summary(authority)
    {
      id: authority.id,
      name: authority.name,
      full_name: authority.full_name,
      prefecture: authority.prefecture,
      city: authority.city,
      authority_type: authority.authority_type.humanize,
      contact_email: authority.contact_email,
      phone_number: authority.phone_number,
      address: authority.full_address,
      status: authority.status,
      currently_open: authority.currently_open?,
      integration_status: authority.integration_status,
      last_sync: authority.last_api_sync_at
    }
  end

  def detailed_authority_data(authority)
    {
      **authority_summary(authority),
      jurisdiction_area: authority.jurisdiction_area,
      api_integration_available: authority.api_integration_available?,
      working_hours: authority.working_hours,
      statistics: authority.statistics,
      contacts_count: authority.municipal_contacts.active.count,
      subsidy_programs_count: authority.subsidy_programs.active.count,
      permit_applications_count: authority.permit_applications.count,
      created_at: authority.created_at,
      updated_at: authority.updated_at
    }
  end

  def subsidy_program_summary(program)
    {
      id: program.id,
      name: program.name,
      description: program.description,
      grant_range: "¥#{program.min_grant_amount.to_s(:delimited)} - ¥#{program.max_grant_amount.to_s(:delimited)}",
      remaining_budget: "¥#{program.remaining_budget.to_s(:delimited)}",
      application_deadline: program.application_end_date,
      accepting_applications: program.accepting_applications?,
      status: program.status
    }
  end

  def authorize_admin!
    unless current_user.admin?
      render_forbidden("Admin access required")
    end
  end
end
