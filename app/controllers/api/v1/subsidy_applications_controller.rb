# frozen_string_literal: true

# API controller for subsidy application operations
# Handles government subsidy application workflow and document management
class Api::V1::SubsidyApplicationsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_subsidy_application, except: [ :index, :create, :statistics ]
  before_action :set_festival, only: [ :index, :create ]
  before_action :authorize_access!, except: [ :index, :create, :statistics ]

  # GET /api/v1/festivals/:festival_id/subsidy_applications
  # GET /api/v1/subsidy_applications
  def index
    @applications = if params[:festival_id]
                     @festival.subsidy_applications
    else
                     SubsidyApplication.all
    end

    # Apply filters
    @applications = @applications.by_program(SubsidyProgram.find(params[:program_id])) if params[:program_id].present?
    @applications = @applications.where(status: params[:status]) if params[:status].present?
    @applications = @applications.by_amount_range(params[:min_amount], params[:max_amount]) if params[:min_amount] && params[:max_amount]
    @applications = @applications.pending if params[:pending_only] == "true"
    @applications = @applications.deadline_approaching if params[:deadline_approaching] == "true"

    # Include associations
    @applications = @applications.includes(:festival, :subsidy_program, :submitted_by, :subsidy_documents)

    # Pagination
    page = params[:page] || 1
    per_page = [ params[:per_page]&.to_i || 20, 100 ].min
    @applications = @applications.page(page).per(per_page)

    render json: {
      success: true,
      data: {
        subsidy_applications: @applications.map { |app| application_summary(app) },
        pagination: pagination_meta(@applications),
        filters: {
          statuses: SubsidyApplication::STATUSES
        }
      }
    }
  end

  # GET /api/v1/subsidy_applications/:id
  def show
    render json: {
      success: true,
      data: {
        subsidy_application: detailed_application_data(@application)
      }
    }
  end

  # POST /api/v1/festivals/:festival_id/subsidy_applications
  def create
    @application = @festival.subsidy_applications.build(application_params)
    @application.submitted_by = current_user

    if @application.save
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application)
        },
        message: "Subsidy application created successfully"
      }, status: :created
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/subsidy_applications/:id
  def update
    if @application.update(application_params)
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application)
        },
        message: "Subsidy application updated successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/subsidy_applications/:id
  def destroy
    if @application.destroy
      render json: {
        success: true,
        message: "Subsidy application deleted successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/subsidy_applications/:id/submit
  def submit
    if @application.submit!
      # Integrate with municipal system if available
      if @application.subsidy_program.municipal_authority.api_integration_available?
        integration_service = MunicipalIntegrationService.new(@application.subsidy_program.municipal_authority)
        integration_result = integration_service.submit_subsidy_application(@application)

        unless integration_result[:success]
          Rails.logger.warn "Municipal integration failed: #{integration_result[:error]}"
        end
      end

      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application.reload)
        },
        message: "Subsidy application submitted successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/subsidy_applications/:id/approve
  def approve
    authorize_reviewer!

    granted_amount = params.require(:granted_amount).to_f
    conditions = params[:conditions]
    notes = params[:notes]

    if @application.approve!(current_user, granted_amount: granted_amount, conditions: conditions, notes: notes)
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application.reload)
        },
        message: "Subsidy application approved successfully"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/subsidy_applications/:id/reject
  def reject
    authorize_reviewer!

    reason = params.require(:reason)
    notes = params[:notes]

    if @application.reject!(current_user, reason: reason, notes: notes)
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application.reload)
        },
        message: "Subsidy application rejected"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/subsidy_applications/:id/request_additional_info
  def request_additional_info
    authorize_reviewer!

    requested_info = params.require(:requested_info)

    if @application.request_additional_info!(current_user, requested_info: requested_info)
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application.reload)
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

  # POST /api/v1/subsidy_applications/:id/provide_additional_info
  def provide_additional_info
    info_provided = params.require(:info_provided)

    if @application.provide_additional_info!(info_provided)
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application.reload)
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

  # POST /api/v1/subsidy_applications/:id/withdraw
  def withdraw
    reason = params[:reason]

    if @application.withdraw!(reason: reason)
      render json: {
        success: true,
        data: {
          subsidy_application: detailed_application_data(@application.reload)
        },
        message: "Subsidy application withdrawn"
      }
    else
      render json: {
        success: false,
        errors: @application.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/subsidy_applications/:id/calculate_grant
  def calculate_grant
    festival_budget = params[:festival_budget]&.to_f || @application.festival.total_budget
    requested_amount = params[:requested_amount]&.to_f || @application.requested_amount

    calculated_amount = @application.subsidy_program.calculate_grant_amount(festival_budget, requested_amount)

    render json: {
      success: true,
      data: {
        festival_budget: festival_budget,
        requested_amount: requested_amount,
        calculated_grant_amount: calculated_amount,
        grant_type: @application.subsidy_program.grant_type,
        program_limits: {
          min_grant: @application.subsidy_program.min_grant_amount,
          max_grant: @application.subsidy_program.max_grant_amount,
          remaining_budget: @application.subsidy_program.remaining_budget
        }
      }
    }
  end

  # GET /api/v1/subsidy_applications/:id/documents
  def documents
    documents = @application.subsidy_documents.includes(:uploaded_by)

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

  # POST /api/v1/subsidy_applications/:id/documents
  def upload_document
    file = params[:file]
    document_type = params[:document_type]

    return render_error("File is required", :bad_request) unless file.present?
    return render_error("Document type is required", :bad_request) unless document_type.present?

    document = @application.subsidy_documents.build(
      document_type: document_type,
      uploaded_by: current_user
    )

    document.file.attach(file)

    if document.save
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

  # GET /api/v1/subsidy_applications/:id/status
  def status
    # Check external status if integrated
    if @application.subsidy_program.municipal_authority.api_integration_available? && @application.external_reference_id.present?
      integration_service = MunicipalIntegrationService.new(@application.subsidy_program.municipal_authority)
      integration_result = integration_service.check_subsidy_status(@application)

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
        review_deadline: @application.review_deadline,
        overdue: @application.overdue?,
        impact_score: @application.impact_score,
        calculated_grant_amount: @application.calculated_grant_amount,
        granted_amount: @application.granted_amount,
        external_status: @application.external_status,
        last_updated: @application.updated_at
      }
    }
  end

  # GET /api/v1/subsidy_applications/:id/impact_analysis
  def impact_analysis
    render json: {
      success: true,
      data: {
        impact_score: @application.impact_score,
        budget_breakdown: @application.budget_breakdown,
        budget_breakdown_percentage: @application.budget_breakdown_percentage,
        community_impact_metrics: @application.community_impact_metrics,
        performance_indicators: @application.performance_indicators,
        risk_mitigation_plan: @application.risk_mitigation_plan,
        expected_outcomes: @application.expected_outcomes
      }
    }
  end

  # GET /api/v1/subsidy_applications/statistics
  def statistics
    authorize_admin_or_reviewer!

    period = params[:period]&.to_i&.days || 30.days

    stats = {
      overview: SubsidyApplication.statistics(period: period),
      by_program: SubsidyApplication.joins(:subsidy_program)
                                   .where(created_at: period.ago..Time.current)
                                   .group("subsidy_programs.name").count,
      by_authority: SubsidyApplication.joins(subsidy_program: :municipal_authority)
                                     .where(created_at: period.ago..Time.current)
                                     .group("municipal_authorities.name").count,
      grant_amounts: SubsidyApplication.average_grants_by_category,
      deadline_approaching: SubsidyApplication.deadline_approaching.count,
      impact_scores: {
        average: SubsidyApplication.approved.average("impact_score"),
        high_impact: SubsidyApplication.approved.where("impact_score >= 80").count,
        medium_impact: SubsidyApplication.approved.where("impact_score >= 60 AND impact_score < 80").count,
        low_impact: SubsidyApplication.approved.where("impact_score < 60").count
      }
    }

    render json: {
      success: true,
      data: stats
    }
  end

  private

  def set_subsidy_application
    @application = SubsidyApplication.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Subsidy application not found")
  end

  def set_festival
    @festival = Festival.find(params[:festival_id]) if params[:festival_id]
  rescue ActiveRecord::RecordNotFound
    render_not_found("Festival not found")
  end

  def application_params
    params.require(:subsidy_application).permit(
      :subsidy_program_id, :requested_amount, :project_description,
      :expected_outcomes, :contact_name, :contact_email, :contact_phone,
      :funding_stage, budget_breakdown: {}, project_timeline: {},
      performance_indicators: [], community_impact_metrics: {},
      risk_mitigation_plan: {}
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
      festival_name: application.festival.name,
      program_name: application.subsidy_program.name,
      authority_name: application.subsidy_program.municipal_authority.name,
      status: application.status.humanize,
      requested_amount: "¥#{application.requested_amount.to_s(:delimited)}",
      granted_amount: application.granted_amount ? "¥#{application.granted_amount.to_s(:delimited)}" : nil,
      processing_days: application.processing_days,
      review_deadline: application.review_deadline,
      overdue: application.overdue?,
      progress_percentage: application.progress_percentage,
      impact_score: application.impact_score,
      submitted_at: application.submitted_at
    }
  end

  def detailed_application_data(application)
    {
      **application_summary(application),
      project_description: application.project_description,
      expected_outcomes: application.expected_outcomes,
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
      budget_breakdown: application.budget_breakdown,
      budget_breakdown_percentage: application.budget_breakdown_percentage,
      project_timeline: application.project_timeline,
      performance_indicators: application.performance_indicators,
      community_impact_metrics: application.community_impact_metrics,
      risk_mitigation_plan: application.risk_mitigation_plan,
      funding_stage: application.funding_stage,
      calculated_grant_amount: application.calculated_grant_amount,
      approval_conditions: application.approval_conditions,
      rejection_reason: application.rejection_reason,
      reviewer_notes: application.reviewer_notes,
      required_documents: application.required_documents,
      missing_documents: application.missing_documents,
      all_documents_uploaded: application.all_documents_uploaded?,
      can_approve: application.can_approve?,
      can_reject: application.can_reject?,
      external_reference_id: application.external_reference_id,
      external_status: application.external_status,
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
