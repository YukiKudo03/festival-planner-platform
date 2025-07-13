class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_user!
  before_action :set_default_response_format
  before_action :set_api_headers
  before_action :log_api_request
  after_action :record_api_metrics
  
  protect_from_forgery with: :null_session
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from JWT::DecodeError, with: :invalid_token
  rescue_from JWT::ExpiredSignature, with: :expired_token
  rescue_from ApiAuthenticationError, with: :authentication_failed
  rescue_from ApiAuthorizationError, with: :authorization_failed
  rescue_from StandardError, with: :internal_server_error
  
  private
  
  def authenticate_api_user!
    @request_start_time = Time.current
    
    # 複数の認証方法をサポート
    auth_result = authenticate_with_jwt || authenticate_with_api_key || authenticate_with_legacy_token
    
    unless auth_result
      raise ApiAuthenticationError, '有効な認証情報が必要です'
    end
    
    # IP制限の確認
    verify_ip_access!
    
    # レート制限の確認
    verify_rate_limits!
    
    # APIキーが取り消されていないかチェック
    verify_api_key_status! if @current_api_key
    
    # 最終アクセス時間の更新
    update_last_access!
  end
  
  # JWT認証
  def authenticate_with_jwt
    auth_header = request.headers['Authorization']
    return false unless auth_header&.start_with?('Bearer ')
    
    token = auth_header.sub(/^Bearer /, '')
    return false if token.blank?
    
    # JWTトークンの検証
    @current_api_user = JwtTokenService.user_from_token(token, token_type: 'access')
    return false unless @current_api_user
    
    # トークンが取り消されていないかチェック
    return false if JwtTokenService.token_revoked?(token)
    
    @authentication_method = 'jwt'
    @jwt_token = token
    @token_scopes = JwtTokenService.token_scopes(token)
    
    true
  rescue JWT::DecodeError, JWT::ExpiredSignature
    false
  end
  
  # APIキー認証
  def authenticate_with_api_key
    api_key = request.headers['X-API-Key'] || params[:api_key]
    return false if api_key.blank?
    
    @current_api_key = ApiKey.active.find_by(api_key: api_key)
    return false unless @current_api_key
    
    @current_api_user = @current_api_key.user
    @authentication_method = 'api_key'
    @token_scopes = @current_api_key.scopes
    
    true
  end
  
  # レガシートークン認証（後方互換性のため）
  def authenticate_with_legacy_token
    auth_header = request.headers['Authorization']
    return false unless auth_header&.start_with?('Bearer ')
    
    token = auth_header.sub(/^Bearer /, '')
    return false if token.blank?
    
    # 従来のAPIトークン形式
    return false if token.length < 32 # JWTではない短いトークン
    
    @current_api_user = User.find_by(api_token: token)
    return false unless @current_api_user
    
    @authentication_method = 'legacy_token'
    @token_scopes = ['legacy:full_access'] # レガシートークンはフルアクセス
    
    true
  end
  
  def verify_ip_access!
    client_ip = request.remote_ip
    
    # APIキー使用時のIP制限
    if @current_api_key && !@current_api_key.can_access_ip?(client_ip)
      raise ApiAuthorizationError, 'このIPアドレスからのアクセスは許可されていません'
    end
    
    # ユーザーのIP制限（設定されている場合）
    if @current_api_user.api_ip_whitelist.present? && 
       !@current_api_user.api_ip_whitelist.include?(client_ip)
      raise ApiAuthorizationError, 'このIPアドレスからのアクセスは許可されていません'
    end
  end
  
  def verify_rate_limits!
    # APIキーレベルの制限
    if @current_api_key && !@current_api_key.within_rate_limit?
      raise ApiAuthorizationError, 'APIキーのレート制限に達しました'
    end
    
    # ユーザーレベルの制限
    cache_key = "api_rate_limit:#{@current_api_user.id}:#{Time.current.to_i / 3600}"
    hourly_requests = Rails.cache.read(cache_key) || 0
    
    max_hourly_requests = determine_rate_limit
    
    if hourly_requests >= max_hourly_requests
      raise ApiAuthorizationError, 'レート制限に達しました。1時間後に再試行してください'
    end
    
    Rails.cache.write(cache_key, hourly_requests + 1, expires_in: 1.hour)
  end
  
  def verify_api_key_status!
    if @current_api_key.expired?
      raise ApiAuthorizationError, 'APIキーの有効期限が切れています'
    end
    
    if @current_api_key.revoked?
      raise ApiAuthorizationError, 'APIキーが取り消されています'
    end
  end
  
  def update_last_access!
    @current_api_user.update_column(:last_api_access_at, Time.current)
    @current_api_key&.update_column(:last_used_at, Time.current)
  end
  
  def current_api_user
    @current_api_user
  end

  def current_api_key
    @current_api_key
  end

  def authentication_method
    @authentication_method
  end

  def token_scopes
    @token_scopes || []
  end
  
  # スコープベースの認可
  def require_scope(required_scope)
    unless has_scope?(required_scope)
      raise ApiAuthorizationError, "Required scope: #{required_scope}"
    end
  end
  
  def has_scope?(scope)
    token_scopes.include?(scope.to_s) || 
    token_scopes.include?('legacy:full_access') ||
    (@current_api_user&.admin? && token_scopes.include?('admin:read'))
  end
  
  # API ヘッダーの設定
  def set_api_headers
    response.headers['X-API-Version'] = 'v1'
    response.headers['X-Rate-Limit-Limit'] = determine_rate_limit.to_s
    response.headers['X-Rate-Limit-Remaining'] = calculate_remaining_requests.to_s
    response.headers['X-Rate-Limit-Reset'] = next_reset_time.to_i.to_s
  end
  
  # APIリクエストのログ記録
  def log_api_request
    @request_info = {
      endpoint: "#{request.method} #{request.path}",
      method: request.method,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      api_version: api_version,
      authentication_method: @authentication_method
    }
  end
  
  # API メトリクスの記録
  def record_api_metrics
    return unless @current_api_user && @request_start_time
    
    response_time = ((Time.current - @request_start_time) * 1000).round(2)
    
    # APIキーのリクエスト記録
    if @current_api_key
      @current_api_key.record_request!(@request_info.merge(
        status: response.status,
        response_time_ms: response_time
      ))
    end
    
    # セキュリティアラートのチェック
    check_security_alerts if @current_api_key&.security_alert_needed?
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
  
  # 新しいエラーハンドリング
  def invalid_token(exception)
    Rails.logger.warn "Invalid JWT token: #{exception.message}"
    render_error('無効なトークンです', :unauthorized)
  end
  
  def expired_token(exception)
    Rails.logger.info "Expired JWT token: #{exception.message}"
    render_error('トークンの有効期限が切れています', :unauthorized)
  end
  
  def authentication_failed(exception)
    Rails.logger.warn "API authentication failed: #{exception.message}"
    render_error(exception.message, :unauthorized)
  end
  
  def authorization_failed(exception)
    Rails.logger.warn "API authorization failed: #{exception.message}"
    render_error(exception.message, :forbidden)
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
  
  # レート制限関連のヘルパー
  def determine_rate_limit
    return @current_api_key.rate_limits['requests_per_hour'] if @current_api_key
    
    case @current_api_user&.role
    when 'admin', 'system_admin'
      5000
    when 'committee_member'
      2000
    else
      1000
    end
  end
  
  def calculate_remaining_requests
    cache_key = "api_rate_limit:#{@current_api_user.id}:#{Time.current.to_i / 3600}"
    used_requests = Rails.cache.read(cache_key) || 0
    [determine_rate_limit - used_requests, 0].max
  end
  
  def next_reset_time
    Time.current.beginning_of_hour + 1.hour
  end
  
  # セキュリティアラート
  def check_security_alerts
    # セキュリティチームに通知を送信
    SecurityAlertJob.perform_later(
      user: @current_api_user,
      api_key: @current_api_key,
      request_info: @request_info,
      alert_type: 'suspicious_api_usage'
    )
  end
end