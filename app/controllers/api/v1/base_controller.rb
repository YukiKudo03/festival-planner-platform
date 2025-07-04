class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_user!
  before_action :set_default_response_format
  
  protect_from_forgery with: :null_session
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from StandardError, with: :internal_server_error
  
  private
  
  def authenticate_api_user!
    token = request.headers['Authorization']&.sub(/^Bearer /, '')
    
    if token.blank?
      render_error('認証トークンが必要です', :unauthorized)
      return
    end
    
    @current_api_user = User.find_by(api_token: token)
    
    unless @current_api_user
      render_error('無効な認証トークンです', :unauthorized)
      return
    end
    
    # Update last API access time
    @current_api_user.update_column(:last_api_access_at, Time.current)
  end
  
  def current_api_user
    @current_api_user
  end
  
  def set_default_response_format
    request.format = :json unless params[:format]
  end
  
  def render_success(data = {}, message = nil, status = :ok)
    response_data = {
      success: true,
      data: data
    }
    response_data[:message] = message if message
    
    render json: response_data, status: status
  end
  
  def render_error(message, status = :bad_request, errors = nil)
    response_data = {
      success: false,
      message: message
    }
    response_data[:errors] = errors if errors
    
    render json: response_data, status: status
  end
  
  def render_pagination(collection, serializer = nil, meta = {})
    pagination_meta = {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value,
      has_next_page: collection.next_page.present?,
      has_prev_page: collection.prev_page.present?
    }.merge(meta)
    
    data = if serializer
             collection.map { |item| serializer.new(item).as_json }
           else
             collection.as_json
           end
    
    render json: {
      success: true,
      data: data,
      meta: pagination_meta
    }
  end
  
  # Error handling methods
  def record_not_found(exception)
    render_error('リソースが見つかりません', :not_found)
  end
  
  def record_invalid(exception)
    render_error(
      'バリデーションエラーが発生しました',
      :unprocessable_entity,
      exception.record.errors.full_messages
    )
  end
  
  def parameter_missing(exception)
    render_error(
      "必須パラメータが不足しています: #{exception.param}",
      :bad_request
    )
  end
  
  def internal_server_error(exception)
    Rails.logger.error "API Error: #{exception.class.name} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    if Rails.env.development?
      render_error(
        exception.message,
        :internal_server_error,
        { backtrace: exception.backtrace[0..10] }
      )
    else
      render_error('内部サーバーエラーが発生しました', :internal_server_error)
    end
  end
  
  # Pagination helpers
  def paginate_collection(collection, per_page: 25)
    page = params[:page] || 1
    per_page = [params[:per_page]&.to_i || per_page, 100].min
    
    collection.page(page).per(per_page)
  end
  
  # Filtering helpers
  def apply_filters(collection, allowed_filters = [])
    return collection if params[:filters].blank?
    
    filters = JSON.parse(params[:filters]) rescue {}
    
    filters.each do |key, value|
      next unless allowed_filters.include?(key.to_sym)
      next if value.blank?
      
      case key.to_sym
      when :search
        collection = collection.where("name ILIKE ?", "%#{value}%")
      when :status
        collection = collection.where(status: value)
      when :created_after
        collection = collection.where("created_at >= ?", Date.parse(value))
      when :created_before
        collection = collection.where("created_at <= ?", Date.parse(value))
      when :festival_id
        collection = collection.where(festival_id: value)
      when :user_id
        collection = collection.where(user_id: value)
      end
    end
    
    collection
  end
  
  # Sorting helpers
  def apply_sorting(collection, default_sort = { created_at: :desc })
    sort_params = params[:sort] || default_sort
    
    if sort_params.is_a?(String)
      sort_params = JSON.parse(sort_params) rescue default_sort
    end
    
    sort_params.each do |field, direction|
      next unless ['asc', 'desc'].include?(direction.to_s.downcase)
      
      if collection.column_names.include?(field.to_s)
        collection = collection.order(field => direction)
      end
    end
    
    collection
  end
  
  # Rate limiting (basic implementation)
  def check_rate_limit
    cache_key = "api_rate_limit:#{current_api_user.id}:#{Time.current.to_i / 60}"
    current_requests = Rails.cache.read(cache_key) || 0
    
    if current_requests >= 100 # 100 requests per minute
      render_error('レート制限に達しました。しばらく待ってから再試行してください。', :too_many_requests)
      return false
    end
    
    Rails.cache.write(cache_key, current_requests + 1, expires_in: 1.minute)
    true
  end
  
  # API versioning helpers
  def api_version
    @api_version ||= request.headers['API-Version'] || 'v1'
  end
  
  def require_api_version(version)
    unless api_version == version
      render_error("APIバージョン #{version} が必要です", :bad_request)
      return false
    end
    true
  end
end