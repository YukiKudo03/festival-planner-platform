# Security configuration for Festival Planner Platform
# This file contains security-related settings and middleware configuration

Rails.application.configure do
  # Security headers configuration
  config.force_ssl = Rails.env.production?
  
  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, 'blob:'
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, 'wss:', 'ws:'
    policy.frame_src   :self, :https
    policy.media_src   :self, :https, :data
    policy.worker_src  :self, :blob
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self, :https
    policy.upgrade_insecure_requests true if Rails.env.production?
  end

  # Security headers
  config.force_ssl = true if Rails.env.production?
  config.ssl_options = {
    hsts: {
      expires: 1.year,
      subdomains: true,
      preload: true
    },
    secure_cookies: true,
    httponly_cookies: true
  } if Rails.env.production?

  # Session configuration
  config.session_store :cookie_store,
    key: '_festival_planner_platform_session',
    secure: Rails.env.production?,
    httponly: true,
    same_site: :strict,
    expire_after: 24.hours

  # CSRF protection
  config.force_ssl = true if Rails.env.production?
end

# Rack::Attack configuration for rate limiting
class Rack::Attack
  # Throttle all requests by IP (60rpm)
  throttle('req/ip', limit: 60, period: 1.minute) do |req|
    req.ip unless req.path.start_with?('/assets/')
  end

  # Throttle login attempts by IP (5 attempts per minute)
  throttle('logins/ip', limit: 5, period: 1.minute) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email
  throttle('logins/email', limit: 5, period: 1.minute) do |req|
    if req.path == '/login' && req.post?
      req.params['email'].presence
    end
  end

  # Throttle password reset attempts
  throttle('password_resets/ip', limit: 3, period: 1.minute) do |req|
    if req.path == '/password/reset' && req.post?
      req.ip
    end
  end

  # Throttle API requests
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end

  # Block requests from known bad IPs
  blocklist('block bad IPs') do |req|
    # Add known malicious IPs here
    # %w[1.2.3.4 5.6.7.8].include?(req.ip)
    false
  end

  # Allow specific IPs (whitelist)
  safelist('allow admin IPs') do |req|
    # Add admin/trusted IPs here
    # %w[127.0.0.1 ::1].include?(req.ip)
    false
  end

  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{ error: 'Rate limit exceeded', retry_after: retry_after }.to_json]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    [
      403,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Forbidden' }.to_json]
    ]
  end
end

# Security headers middleware
class SecurityHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Add security headers
    headers['X-Frame-Options'] = 'DENY'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
    
    # Remove server header
    headers.delete('Server')
    
    # Add HSTS header for HTTPS
    if env['HTTPS'] == 'on' || env['HTTP_X_FORWARDED_PROTO'] == 'https'
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'
    end

    [status, headers, response]
  end
end

# Parameter sanitization
class ParameterSanitizer
  SENSITIVE_PARAMS = %w[
    password
    password_confirmation
    current_password
    secret
    token
    api_key
    private_key
    credit_card_number
    cvv
    ssn
    social_security_number
  ].freeze

  def self.sanitize(params)
    params.deep_transform_keys(&:to_s).tap do |sanitized|
      SENSITIVE_PARAMS.each do |param|
        sanitized.deep_transform_values! do |value|
          if value.is_a?(String) && sensitive_value?(value)
            '[FILTERED]'
          else
            value
          end
        end
      end
    end
  end

  private

  def self.sensitive_value?(value)
    SENSITIVE_PARAMS.any? { |param| value.downcase.include?(param) }
  end
end

# SQL injection prevention
module ActiveRecord
  class Base
    # Override find_by_sql to add basic SQL injection protection
    def self.find_by_sql(sql, binds = [], preparable: nil, &block)
      # Basic SQL injection detection
      if sql.is_a?(String) && sql.match?(/('|(\\x27)|(\\x2D)|(;)|(\||(\*)|(%))/)
        Rails.logger.warn "Potential SQL injection attempt detected: #{sql}"
        raise ActiveRecord::StatementInvalid, "Potentially unsafe SQL query"
      end
      
      super
    end
  end
end

# XSS prevention helpers
module XSSProtection
  def sanitize_user_input(input)
    return input unless input.is_a?(String)
    
    ActionController::Base.helpers.sanitize(
      input,
      tags: %w[b i u strong em p br ul ol li a],
      attributes: %w[href]
    )
  end

  def strip_dangerous_html(input)
    return input unless input.is_a?(String)
    
    ActionController::Base.helpers.strip_tags(input)
  end
end

# File upload security
class SecureFileUpload
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/gif
    image/webp
    application/pdf
    text/plain
    text/csv
  ].freeze

  MAX_FILE_SIZE = 10.megabytes

  def self.validate_upload(file)
    errors = []

    # Check file size
    if file.size > MAX_FILE_SIZE
      errors << "File size exceeds maximum allowed size (#{MAX_FILE_SIZE / 1.megabyte}MB)"
    end

    # Check content type
    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      errors << "File type not allowed. Allowed types: #{ALLOWED_CONTENT_TYPES.join(', ')}"
    end

    # Check file extension
    extension = File.extname(file.original_filename).downcase
    allowed_extensions = %w[.jpg .jpeg .png .gif .webp .pdf .txt .csv]
    unless allowed_extensions.include?(extension)
      errors << "File extension not allowed"
    end

    # Scan for malicious content (basic check)
    if file.content_type.start_with?('image/') && !valid_image?(file)
      errors << "Invalid image file"
    end

    errors
  end

  private

  def self.valid_image?(file)
    # Basic image validation using ImageMagick/MiniMagick
    begin
      image = MiniMagick::Image.new(file.tempfile.path)
      image.valid?
    rescue
      false
    end
  end
end

# API security
module APISecurityConcern
  extend ActiveSupport::Concern

  included do
    before_action :validate_api_version
    before_action :rate_limit_api_requests
    before_action :authenticate_api_request
  end

  private

  def validate_api_version
    version = request.headers['API-Version']
    unless %w[v1 v2].include?(version)
      render json: { error: 'Invalid API version' }, status: 400
    end
  end

  def rate_limit_api_requests
    # Additional API-specific rate limiting
    key = "api_rate_limit:#{request.ip}"
    current_requests = Rails.cache.read(key) || 0
    
    if current_requests >= 1000
      render json: { error: 'API rate limit exceeded' }, status: 429
      return
    end
    
    Rails.cache.write(key, current_requests + 1, expires_in: 1.hour)
  end

  def authenticate_api_request
    token = request.headers['Authorization']&.remove('Bearer ')
    
    unless token && valid_api_token?(token)
      render json: { error: 'Invalid API token' }, status: 401
    end
  end

  def valid_api_token?(token)
    # Implement your API token validation logic here
    # This could involve JWT verification, database lookup, etc.
    true
  end
end

# Logging security events
class SecurityEventLogger
  def self.log_security_event(event_type, details = {})
    Rails.logger.warn({
      event: 'SECURITY_EVENT',
      type: event_type,
      timestamp: Time.current.iso8601,
      ip: details[:ip],
      user_id: details[:user_id],
      user_agent: details[:user_agent],
      details: details[:additional_info]
    }.to_json)
  end

  def self.log_failed_login(ip, email, user_agent)
    log_security_event('FAILED_LOGIN', {
      ip: ip,
      email: email,
      user_agent: user_agent
    })
  end

  def self.log_suspicious_activity(ip, activity, user_agent)
    log_security_event('SUSPICIOUS_ACTIVITY', {
      ip: ip,
      activity: activity,
      user_agent: user_agent
    })
  end

  def self.log_privilege_escalation(user_id, action, ip)
    log_security_event('PRIVILEGE_ESCALATION', {
      user_id: user_id,
      action: action,
      ip: ip
    })
  end
end