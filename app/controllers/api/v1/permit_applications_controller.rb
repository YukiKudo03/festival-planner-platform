# frozen_string_literal: true

# API controller for permit application operations
# Handles government permit application workflow and document management
class Api::V1::PermitApplicationsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_permit_application, except: [ :index, :create, :statistics ]
  before_action :set_festival, only: [ :index, :create ]
  before_action :authorize_access!, except: [ :index, :create, :statistics ]

  # GET /api/v1/festivals/:festival_id/permit_applications
  # GET /api/v1/permit_applications
  def index
    @applications = if params[:festival_id]
                     @festival.permit_applications
    else
                     PermitApplication.all
    end

    # Apply filters
    @applications = @applications.by_permit_type(params[:permit_type]) if params[:permit_type].present?
    @applications = @applications.where(status: params[:status]) if params[:status].present?
    @applications = @applications.by_authority(MunicipalAuthority.find(params[:authority_id])) if params[:authority_id].present?
    @applications = @applications.pending if params[:pending_only] == "true"
    @applications = @applications.overdue if params[:overdue_only] == "true"

    # Include associations
    @applications = @applications.includes(:festival, :municipal_authority, :submitted_by, :permit_documents)

    # Pagination
    page = params[:page] || 1
    per_page = [ params[:per_page]&.to_i || 20, 100 ].min
    @applications = @applications.page(page).per(per_page)

    render json: {
      success: true,
      data: {
        permit_applications: @applications.map { |app| application_summary(app) },
        pagination: pagination_meta(@applications),
        filters: {
          permit_types: PermitApplication::PERMIT_TYPES,
          statuses: PermitApplication::STATUSES
        }
      }
    }
  end

  # GET /api/v1/permit_applications/:id
  def show
    render json: {
      success: true,
      data: {
        permit_application: detailed_application_data(@application)
      }
    }
  end

  # POST /api/v1/festivals/:festival_id/permit_applications
  def create
    @application = @festival.permit_applications.build(application_params)
    @application.submitted_by = current_user

    if @application.save
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application)
        },
        message: "Permit application created successfully"
      }, status: :created
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/permit_applications/:id
  def update
    if @application.update(application_params)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application)
        },
        message: "Permit application updated successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/permit_applications/:id
  def destroy
    if @application.destroy
      render json: {
        success: true,
        message: "Permit application deleted successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/submit
  def submit
    if @application.submit!
      # Integrate with municipal system if available
      if @application.municipal_authority.api_integration_available?
        integration_service = MunicipalIntegrationService.new(@application.municipal_authority)
        integration_result = integration_service.submit_permit_application(@application)

        unless integration_result[:success]
          Rails.logger.warn "Municipal integration failed: #{integration_result[:error]}"
        end
      end

      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Permit application submitted successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/approve
  def approve
    authorize_reviewer!

    notes = params[:notes]

    if @application.approve!(current_user, notes: notes)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Permit application approved successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/reject
  def reject
    authorize_reviewer!

    notes = params.require(:notes)

    if @application.reject!(current_user, notes: notes)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Permit application rejected"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/request_additional_info
  def request_additional_info
    authorize_reviewer!

    requested_info = params.require(:requested_info)

    if @application.request_additional_info!(current_user, requested_info: requested_info)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Additional information requested"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/provide_additional_info
  def provide_additional_info
    info_provided = params.require(:info_provided)

    if @application.provide_additional_info!(info_provided)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Additional information provided"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/cancel
  def cancel
    reason = params[:reason]

    if @application.cancel!(reason: reason)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Permit application cancelled"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/permit_applications/:id/pay_fee
  def pay_fee
    payment_reference = params[:payment_reference]

    if @application.record_fee_payment!(payment_reference: payment_reference)
      render json: {
        success: true,
        data: {
          permit_application: detailed_application_data(@application.reload)
        },
        message: "Permit fee payment recorded"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/permit_applications/:id/documents
  def documents
    documents = @application.permit_documents.includes(:uploaded_by)

    render json: {
      success: true,
      data: {
        documents: documents.map { |doc| document_summary(doc) },
        required_documents: @application.required_documents,
        missing_documents: @application.missing_documents,
        all_uploaded: @application.all_documents_uploaded?
      }
    }
  end

  # POST /api/v1/permit_applications/:id/documents
  def upload_document
    file = params[:file]
    document_type = params[:document_type]

    return render_error("File is required", :bad_request) unless file.present?
    return render_error("Document type is required", :bad_request) unless document_type.present?

    document = @application.permit_documents.build(
      document_type: document_type,
      uploaded_by: current_user
    )

    document.file.attach(file)

    if document.save
      # Upload to municipal system if available
      if @application.municipal_authority.api_integration_available?
        integration_service = MunicipalIntegrationService.new(@application.municipal_authority)
        integration_result = integration_service.upload_permit_document(@application, document)

        unless integration_result[:success]
          Rails.logger.warn "Document upload integration failed: #{integration_result[:error]}"
        end
      end

      render json: {
        success: true,
        data: {
          document: document_summary(document)
        },
        message: "Document uploaded successfully"
      }, status: :created
    else
      render json: {
        success: false,
        errors: document.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/permit_applications/:id/status
  def status
    # Check external status if integrated
    if @application.municipal_authority.api_integration_available? && @application.external_reference_id.present?
      integration_service = MunicipalIntegrationService.new(@application.municipal_authority)
      integration_result = integration_service.check_permit_status(@application)

      unless integration_result[:success]
        Rails.logger.warn "Status check integration failed: #{integration_result[:error]}"
      end
    end

    render json: {
      success: true,
      data: {
        application_number: @application.application_number,
        status: @application.status,
        progress_percentage: @application.progress_percentage,
        processing_days: @application.processing_days,
        expected_decision_date: @application.expected_decision_date,
        overdue: @application.overdue?,
        fee_amount: @application.permit_fee,
        fee_paid: @application.fee_paid?,
        external_status: @application.external_status,
        last_updated: @application.updated_at
      }
    }
  end

  # GET /api/v1/permit_applications/statistics
  def statistics
    authorize_admin_or_reviewer!

    period = params[:period]&.to_i&.days || 30.days

    stats = {
      overview: PermitApplication.statistics(period: period),
      by_permit_type: PermitApplication.where(created_at: period.ago..Time.current)
                                      .group(:permit_type).count,
      by_authority: PermitApplication.joins(:municipal_authority)
                                    .where(created_at: period.ago..Time.current)
                                    .group("municipal_authorities.name").count,
      processing_times: PermitApplication.average_processing_time_by_type,
      overdue_applications: PermitApplication.overdue.count,
      expiring_soon: PermitApplication.expiring_soon.count
    }

    render json: {
      success: true,
      data: stats
    }
  end

  private

  def set_permit_application
    @application = PermitApplication.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Permit application not found")
  end

  def set_festival
    @festival = Festival.find(params[:festival_id]) if params[:festival_id]
  rescue ActiveRecord::RecordNotFound
    render_not_found("Festival not found")
  end

  def application_params
    params.require(:permit_application).permit(
      :municipal_authority_id, :permit_type, :estimated_attendance,
      :event_start_date, :event_end_date, :venue_address,
      :contact_name, :contact_email, :contact_phone,
      :additional_info, :priority
    )
  end

  def authorize_access!
    unless current_user.admin? || current_user.festival_organizer? ||
           @application.submitted_by == current_user ||
           @application.reviewed_by == current_user
      render_forbidden("Access denied")
    end
  end

  def authorize_reviewer!
    unless current_user.admin? || current_user.government_reviewer?
      render_forbidden("Reviewer access required")
    end
  end

  def authorize_admin_or_reviewer!
    unless current_user.admin? || current_user.government_reviewer?
      render_forbidden("Admin or reviewer access required")
    end
  end

  def application_summary(application)
    {
      id: application.id,
      application_number: application.application_number,
      permit_type: application.permit_type_name,
      status: application.status.humanize,
      festival_name: application.festival.name,
      authority_name: application.municipal_authority.name,
      estimated_attendance: application.estimated_attendance,
      event_dates: "#{application.event_start_date} - #{application.event_end_date}",
      processing_days: application.processing_days,
      expected_decision_date: application.expected_decision_date,
      overdue: application.overdue?,
      progress_percentage: application.progress_percentage,
      submitted_at: application.submitted_at,
      fee_amount: application.permit_fee,
      fee_paid: application.fee_paid?
    }
  end

  def detailed_application_data(application)
    {
      **application_summary(application),
      venue_address: application.venue_address,
      contact_info: {
        name: application.contact_name,
        email: application.contact_email,
        phone: application.contact_phone
      },
      submitted_by: {
        id: application.submitted_by.id,
        name: application.submitted_by.name,
        email: application.submitted_by.email
      },
      reviewed_by: application.reviewed_by ? {
        id: application.reviewed_by.id,
        name: application.reviewed_by.name,
        email: application.reviewed_by.email
      } : nil,
      additional_info: application.additional_info,
      reviewer_notes: application.reviewer_notes,
      required_documents: application.required_documents,
      missing_documents: application.missing_documents,
      all_documents_uploaded: application.all_documents_uploaded?,
      can_approve: application.can_approve?,
      can_reject: application.can_reject?,
      external_reference_id: application.external_reference_id,
      external_status: application.external_status,
      priority: application.priority,
      created_at: application.created_at,
      updated_at: application.updated_at
    }
  end

  def document_summary(document)
    {
      id: document.id,
      document_type: document.document_type_name,
      filename: document.filename,
      file_size: document.human_file_size,
      status: document.status.humanize,
      uploaded_by: document.uploaded_by.name,
      uploaded_at: document.created_at,
      reviewed_at: document.reviewed_at,
      processing_days: document.processing_days,
      download_url: document.download_url
    }
  end
end
