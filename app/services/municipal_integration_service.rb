# frozen_string_literal: true

# Municipal Integration Service for government system integration
# Handles API communication and data synchronization with municipal authorities
class MunicipalIntegrationService
  include HTTParty
  
  # Configuration
  default_timeout 30
  
  def initialize(municipal_authority)
    @authority = municipal_authority
    @api_endpoint = @authority.api_endpoint
    @api_key = @authority.api_key
    
    # Configure HTTParty for this authority
    self.class.base_uri @api_endpoint if @api_endpoint
    self.class.headers({
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}",
      'User-Agent' => 'Festival-Planner-Platform/2.1.0'
    })
  end

  # Permit application operations
  
  def submit_permit_application(permit_application)
    return { success: false, error: 'API not configured' } unless api_configured?
    
    payload = format_permit_application(permit_application)
    
    begin
      response = self.class.post('/permits/applications', {
        body: payload.to_json
      })
      
      handle_permit_response(response, permit_application)
    rescue StandardError => e
      log_error('submit_permit_application', e)
      { success: false, error: e.message }
    end
  end
  
  def check_permit_status(permit_application)
    return { success: false, error: 'API not configured' } unless api_configured?
    return { success: false, error: 'No external reference' } unless permit_application.external_reference_id
    
    begin
      response = self.class.get("/permits/applications/#{permit_application.external_reference_id}")
      
      if response.success?
        status_data = JSON.parse(response.body)
        update_permit_from_external_status(permit_application, status_data)
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('check_permit_status', e)
      { success: false, error: e.message }
    end
  end
  
  def upload_permit_document(permit_application, document)
    return { success: false, error: 'API not configured' } unless api_configured?
    return { success: false, error: 'No external reference' } unless permit_application.external_reference_id
    
    begin
      # Prepare multipart form data
      file_data = {
        file: document.file.blob,
        document_type: document.document_type,
        filename: document.filename
      }
      
      response = self.class.post(
        "/permits/applications/#{permit_application.external_reference_id}/documents",
        body: file_data
      )
      
      if response.success?
        document_data = JSON.parse(response.body)
        document.update(external_document_id: document_data['document_id'])
        { success: true, data: document_data }
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('upload_permit_document', e)
      { success: false, error: e.message }
    end
  end

  # Subsidy program operations
  
  def sync_subsidy_programs
    return { success: false, error: 'API not configured' } unless api_configured?
    
    begin
      response = self.class.get('/subsidies/programs')
      
      if response.success?
        programs_data = JSON.parse(response.body)
        import_subsidy_programs(programs_data)
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('sync_subsidy_programs', e)
      { success: false, error: e.message }
    end
  end
  
  def submit_subsidy_application(subsidy_application)
    return { success: false, error: 'API not configured' } unless api_configured?
    
    payload = format_subsidy_application(subsidy_application)
    
    begin
      response = self.class.post('/subsidies/applications', {
        body: payload.to_json
      })
      
      handle_subsidy_response(response, subsidy_application)
    rescue StandardError => e
      log_error('submit_subsidy_application', e)
      { success: false, error: e.message }
    end
  end
  
  def check_subsidy_status(subsidy_application)
    return { success: false, error: 'API not configured' } unless api_configured?
    return { success: false, error: 'No external reference' } unless subsidy_application.external_reference_id
    
    begin
      response = self.class.get("/subsidies/applications/#{subsidy_application.external_reference_id}")
      
      if response.success?
        status_data = JSON.parse(response.body)
        update_subsidy_from_external_status(subsidy_application, status_data)
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('check_subsidy_status', e)
      { success: false, error: e.message }
    end
  end

  # Authority data synchronization
  
  def sync_authority_data
    return { success: false, error: 'API not configured' } unless api_configured?
    
    begin
      response = self.class.get('/authority/info')
      
      if response.success?
        authority_data = JSON.parse(response.body)
        update_authority_info(authority_data)
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('sync_authority_data', e)
      { success: false, error: e.message }
    end
  end
  
  def sync_contact_information
    return { success: false, error: 'API not configured' } unless api_configured?
    
    begin
      response = self.class.get('/authority/contacts')
      
      if response.success?
        contacts_data = JSON.parse(response.body)
        import_contact_information(contacts_data)
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('sync_contact_information', e)
      { success: false, error: e.message }
    end
  end

  # Health check and diagnostics
  
  def test_connection
    return { success: false, error: 'API not configured' } unless api_configured?
    
    begin
      response = self.class.get('/health')
      
      if response.success?
        health_data = JSON.parse(response.body)
        { success: true, data: health_data }
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('test_connection', e)
      { success: false, error: e.message }
    end
  end
  
  def get_api_status
    return { success: false, error: 'API not configured' } unless api_configured?
    
    begin
      response = self.class.get('/status')
      
      if response.success?
        status_data = JSON.parse(response.body)
        { success: true, data: status_data }
      else
        { success: false, error: "HTTP #{response.code}: #{response.message}" }
      end
    rescue StandardError => e
      log_error('get_api_status', e)
      { success: false, error: e.message }
    end
  end

  private

  def api_configured?
    @api_endpoint.present? && @api_key.present?
  end

  def format_permit_application(permit_application)
    {
      application_type: permit_application.permit_type,
      festival_info: {
        name: permit_application.festival.name,
        description: permit_application.festival.description,
        start_date: permit_application.event_start_date,
        end_date: permit_application.event_end_date,
        expected_attendance: permit_application.estimated_attendance
      },
      venue_info: {
        name: permit_application.festival.venue&.name,
        address: permit_application.venue_address
      },
      contact_info: {
        name: permit_application.contact_name,
        email: permit_application.contact_email,
        phone: permit_application.contact_phone
      },
      additional_info: permit_application.additional_info
    }
  end

  def format_subsidy_application(subsidy_application)
    {
      program_id: subsidy_application.subsidy_program.external_program_id,
      festival_info: {
        name: subsidy_application.festival.name,
        description: subsidy_application.festival.description,
        category: subsidy_application.festival.category,
        expected_attendance: subsidy_application.festival.expected_attendance
      },
      application_info: {
        requested_amount: subsidy_application.requested_amount,
        project_description: subsidy_application.project_description,
        expected_outcomes: subsidy_application.expected_outcomes,
        budget_breakdown: subsidy_application.budget_breakdown
      },
      contact_info: {
        name: subsidy_application.contact_name,
        email: subsidy_application.contact_email,
        phone: subsidy_application.contact_phone
      }
    }
  end

  def handle_permit_response(response, permit_application)
    if response.success?
      response_data = JSON.parse(response.body)
      permit_application.update!(
        external_reference_id: response_data['application_id'],
        external_status: response_data['status']
      )
      { success: true, data: response_data }
    else
      { success: false, error: "HTTP #{response.code}: #{response.message}" }
    end
  end

  def handle_subsidy_response(response, subsidy_application)
    if response.success?
      response_data = JSON.parse(response.body)
      subsidy_application.update!(
        external_reference_id: response_data['application_id'],
        external_status: response_data['status']
      )
      { success: true, data: response_data }
    else
      { success: false, error: "HTTP #{response.code}: #{response.message}" }
    end
  end

  def update_permit_from_external_status(permit_application, status_data)
    # Map external status to internal status
    internal_status = map_external_permit_status(status_data['status'])
    
    if internal_status && permit_application.status != internal_status
      permit_application.update!(
        status: internal_status,
        external_status: status_data['status'],
        external_notes: status_data['notes'],
        last_external_sync: Time.current
      )
    end
    
    { success: true, data: status_data }
  end

  def update_subsidy_from_external_status(subsidy_application, status_data)
    # Map external status to internal status
    internal_status = map_external_subsidy_status(status_data['status'])
    
    if internal_status && subsidy_application.status != internal_status
      subsidy_application.update!(
        status: internal_status,
        external_status: status_data['status'],
        external_notes: status_data['notes'],
        granted_amount: status_data['granted_amount'],
        last_external_sync: Time.current
      )
    end
    
    { success: true, data: status_data }
  end

  def import_subsidy_programs(programs_data)
    imported_count = 0
    
    programs_data.each do |program_data|
      program = @authority.subsidy_programs.find_or_initialize_by(
        external_program_id: program_data['program_id']
      )
      
      program.assign_attributes(
        name: program_data['name'],
        description: program_data['description'],
        total_budget: program_data['total_budget'],
        max_grant_amount: program_data['max_grant_amount'],
        min_grant_amount: program_data['min_grant_amount'],
        application_start_date: program_data['application_start_date'],
        application_end_date: program_data['application_end_date'],
        status: map_external_program_status(program_data['status']),
        eligible_festival_types: program_data['eligible_festival_types']
      )
      
      if program.save
        imported_count += 1
      end
    end
    
    { success: true, imported_count: imported_count }
  end

  def update_authority_info(authority_data)
    @authority.update!(
      name: authority_data['name'],
      contact_email: authority_data['contact_email'],
      phone_number: authority_data['phone_number'],
      address: authority_data['address'],
      working_hours_monday: authority_data.dig('working_hours', 'monday'),
      working_hours_tuesday: authority_data.dig('working_hours', 'tuesday'),
      working_hours_wednesday: authority_data.dig('working_hours', 'wednesday'),
      working_hours_thursday: authority_data.dig('working_hours', 'thursday'),
      working_hours_friday: authority_data.dig('working_hours', 'friday'),
      working_hours_saturday: authority_data.dig('working_hours', 'saturday'),
      working_hours_sunday: authority_data.dig('working_hours', 'sunday'),
      last_api_sync_at: Time.current
    )
    
    { success: true }
  end

  def import_contact_information(contacts_data)
    imported_count = 0
    
    contacts_data.each do |contact_data|
      contact = @authority.municipal_contacts.find_or_initialize_by(
        email: contact_data['email']
      )
      
      contact.assign_attributes(
        name: contact_data['name'],
        phone: contact_data['phone'],
        department: contact_data['department'],
        contact_type: map_external_contact_type(contact_data['contact_type']),
        title: contact_data['title']
      )
      
      if contact.save
        imported_count += 1
      end
    end
    
    { success: true, imported_count: imported_count }
  end

  def map_external_permit_status(external_status)
    case external_status.downcase
    when 'draft' then 'draft'
    when 'submitted', 'received' then 'submitted'
    when 'under_review', 'reviewing' then 'under_review'
    when 'additional_info_required' then 'additional_info_required'
    when 'approved' then 'approved'
    when 'rejected', 'denied' then 'rejected'
    when 'expired' then 'expired'
    when 'cancelled' then 'cancelled'
    else nil
    end
  end

  def map_external_subsidy_status(external_status)
    case external_status.downcase
    when 'draft' then 'draft'
    when 'submitted', 'received' then 'submitted'
    when 'under_review', 'reviewing' then 'under_review'
    when 'additional_info_required' then 'additional_info_required'
    when 'approved' then 'approved'
    when 'rejected', 'denied' then 'rejected'
    when 'withdrawn' then 'withdrawn'
    else nil
    end
  end

  def map_external_program_status(external_status)
    case external_status.downcase
    when 'planned' then 'planned'
    when 'active', 'open' then 'active'
    when 'suspended' then 'suspended'
    when 'closed' then 'closed'
    when 'completed' then 'completed'
    else 'planned'
    end
  end

  def map_external_contact_type(external_type)
    case external_type.downcase
    when 'general' then 'general'
    when 'events', 'event_permits' then 'event_permits'
    when 'fire', 'fire_safety' then 'fire_safety'
    when 'health', 'health_permits' then 'health_permits'
    when 'police', 'security' then 'police_coordination'
    when 'tourism' then 'tourism_support'
    when 'environment' then 'environmental_review'
    when 'emergency' then 'emergency_contact'
    else 'general'
    end
  end

  def log_error(operation, error)
    Rails.logger.error "Municipal API Error [#{@authority.name}] #{operation}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if error.backtrace
  end
end