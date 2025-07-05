# Rate limiting and security configuration
# Skip initialization in test and development environment to avoid Redis dependency
return if Rails.env.test? || Rails.env.development?

class Rack::Attack
  # Configuration
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/1',
    namespace: 'rack_attack'
  )

  # Enable/disable tracking
  Rack::Attack.enabled = Rails.env.production? || Rails.env.staging?

  # Custom throttling function
  def self.throttle_key(discriminator, period, request)
    "throttle:#{discriminator}:#{period}:#{request.ip}"
  end

  # Allow localhost in development
  safelist('allow from localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip || req.ip.in?(['127.0.0.1', '::1'])
  end

  # Allow health check requests
  safelist('health check') do |req|
    req.path == '/up' || req.path == '/health' || req.path == '/nginx_status'
  end

  # Block suspicious requests
  blocklist('block bad user agents') do |req|
    req.user_agent =~ /curl|wget|python|php|java|ruby|go-http-client/i &&
    !req.path.start_with?('/up', '/health')
  end

  # Block requests with suspicious paths
  blocklist('block malicious paths') do |req|
    malicious_paths = %w[
      /wp-admin /wp-login /phpMyAdmin /admin/login
      /.env /.git /config.json /etc/passwd
      /xmlrpc.php /wp-config.php
    ]
    malicious_paths.any? { |path| req.path.include?(path) }
  end

  # Block SQL injection attempts
  blocklist('block sql injection') do |req|
    sql_injection_patterns = [
      /union.*select/i,
      /drop.*table/i,
      /exec.*xp_/i,
      /'.*or.*'.*='/i,
      /';.*--/i
    ]
    
    query_string = req.query_string.to_s
    post_body = req.body.read.to_s rescue ''
    req.body.rewind if req.body.respond_to?(:rewind)
    
    sql_injection_patterns.any? do |pattern|
      query_string.match?(pattern) || post_body.match?(pattern)
    end
  end

  # General rate limiting - 100 requests per minute per IP
  throttle('general requests', limit: 100, period: 1.minute) do |req|
    req.ip unless req.path.start_with?('/assets', '/up', '/health')
  end

  # Stricter rate limiting for authentication endpoints
  throttle('login attempts', limit: 5, period: 5.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  # Rate limit password reset requests
  throttle('password reset', limit: 3, period: 10.minutes) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end

  # Rate limit registration attempts
  throttle('registration', limit: 3, period: 10.minutes) do |req|
    if req.path == '/users' && req.post?
      req.ip
    end
  end

  # API rate limiting - 100 requests per hour per API token
  throttle('api requests per token', limit: 100, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      token = req.env['HTTP_AUTHORIZATION']&.sub(/^Bearer /, '')
      token if token.present?
    end
  end

  # API rate limiting per IP - 500 requests per hour
  throttle('api requests per ip', limit: 500, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      req.ip
    end
  end

  # Payment endpoint rate limiting
  throttle('payment requests', limit: 10, period: 10.minutes) do |req|
    if req.path.include?('/payments') && req.post?
      # Use both IP and authenticated user for tracking
      user_id = req.env['warden']&.user&.id
      "#{req.ip}:#{user_id}" if user_id
    end
  end

  # Admin interface rate limiting
  throttle('admin requests', limit: 50, period: 5.minutes) do |req|
    if req.path.start_with?('/admin')
      req.ip
    end
  end

  # File upload rate limiting
  throttle('file uploads', limit: 5, period: 10.minutes) do |req|
    if req.path.include?('/rails/active_storage') && req.post?
      user_id = req.env['warden']&.user&.id
      "upload:#{req.ip}:#{user_id}" if user_id
    end
  end

  # Search endpoint rate limiting to prevent abuse
  throttle('search requests', limit: 20, period: 1.minute) do |req|
    if req.path.include?('/search') || req.params['q'].present?
      req.ip
    end
  end

  # Exponential backoff for repeated offenders
  throttle('repeat offender', limit: 1, period: 1.hour) do |req|
    # Track IPs that have been throttled multiple times
    cache_key = "repeat_offender:#{req.ip}"
    count = Rack::Attack.cache.read(cache_key) || 0
    
    if count > 3 # After 3 throttling incidents
      req.ip
    end
  end

  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s,
        'X-RateLimit-Limit' => env['rack.attack.match_data'][:limit].to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => (Time.now + retry_after).to_i.to_s
      },
      [{
        error: 'Rate limit exceeded',
        message: 'Too many requests. Please try again later.',
        retry_after: retry_after
      }.to_json]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    [
      403,
      { 'Content-Type' => 'application/json' },
      [{
        error: 'Forbidden',
        message: 'Request blocked for security reasons'
      }.to_json]
    ]
  end

  # Track successful requests for monitoring
  track('successful requests') do |req|
    req.ip unless req.path.start_with?('/assets', '/up', '/health')
  end

  # Track API usage
  track('api usage') do |req|
    if req.path.start_with?('/api/')
      token = req.env['HTTP_AUTHORIZATION']&.sub(/^Bearer /, '')
      "api:#{token}" if token.present?
    end
  end

  # Notification callbacks
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    
    case payload[:name]
    when 'throttle'
      Rails.logger.warn "Rate limit exceeded for #{req.ip} on #{req.path}"
      
      # Update repeat offender counter
      cache_key = "repeat_offender:#{req.ip}"
      count = Rack::Attack.cache.read(cache_key) || 0
      Rack::Attack.cache.write(cache_key, count + 1, expires_in: 1.hour)
      
    when 'blocklist'
      Rails.logger.error "Blocked request from #{req.ip} to #{req.path} - #{payload[:match_type]}"
      
      # Alert on security blocks
      if Rails.env.production?
        # In production, you might want to send alerts to monitoring service
        # SecurityAlertService.notify_blocked_request(req, payload)
      end
      
    when 'track'
      # Log successful API usage for analytics
      if payload[:name] == 'api usage'
        Rails.logger.info "API request from #{req.ip} to #{req.path}"
      end
    end
  end

  # Advanced features for production
  if Rails.env.production?
    # Exponential backoff configuration
    exponential_backoff = lambda do |count|
      case count
      when 1 then 1.minute
      when 2 then 5.minutes
      when 3 then 15.minutes
      when 4 then 1.hour
      else 24.hours
      end
    end

    # Dynamic rate limiting based on server load
    dynamic_limit = lambda do |req|
      base_limit = 100
      # In production, you could check server metrics
      # load_factor = SystemMetrics.current_load
      # (base_limit * (1 - load_factor)).to_i
      base_limit
    end

    # Whitelist known good IPs (CDN, monitoring services, etc.)
    safelist('known good ips') do |req|
      known_good_ips = ENV['WHITELISTED_IPS']&.split(',') || []
      known_good_ips.include?(req.ip)
    end
  end
end

# Configuration for cache warming in production
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Warm up the rate limiting cache
    begin
      Rack::Attack.cache.write('warmup', 'ok', expires_in: 1.minute)
      Rails.logger.info "Rack::Attack cache warmed up successfully"
    rescue => e
      Rails.logger.error "Failed to warm up Rack::Attack cache: #{e.message}"
    end
  end
end