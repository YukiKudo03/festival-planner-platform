require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from CDN
  config.asset_host = ENV['CDN_HOST'] if ENV['CDN_HOST'].present?

  # Store uploaded files on Amazon S3 for production
  config.active_storage.service = :amazon

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use Redis for caching in production for better performance
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
    namespace: 'festival_platform_prod',
    expires_in: 1.hour,
    compress: true,
    compression_threshold: 1.kilobyte
  }

  # Use Sidekiq for background job processing
  config.active_job.queue_adapter = :sidekiq
  config.active_job.queue_name_prefix = "festival_planner_platform_production"

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Action Mailer configuration for production
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { 
    host: ENV['APP_HOST'] || 'localhost:3000',
    protocol: 'https'
  }

  # SMTP configuration using environment variables
  config.action_mailer.smtp_settings = {
    address:              ENV['SMTP_SERVER'] || 'smtp.gmail.com',
    port:                 ENV['SMTP_PORT'] || 587,
    domain:               ENV['SMTP_DOMAIN'] || 'gmail.com',
    user_name:            ENV['SMTP_USERNAME'],
    password:             ENV['SMTP_PASSWORD'],
    authentication:       'plain',
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Database configuration for production with read replicas
  config.active_record.database_selector = { delay: 2.seconds }
  config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session

  # Compress responses for better performance
  config.middleware.use Rack::Deflater

  # Security configurations
  config.ssl_options = {
    secure_cookies: true,
    hsts: {
      expires: 1.year,
      subdomains: true,
      preload: true
    }
  }

  # Content Security Policy for enhanced security
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, "'unsafe-inline'"
    policy.style_src   :self, :https, "'unsafe-inline'"
    policy.connect_src :self, :https, "wss:"
    
    # For Chart.js and analytics
    policy.script_src :self, :https, "'unsafe-eval'", "'unsafe-inline'"
    
    # For payment processing
    policy.frame_src :self, "https://checkout.stripe.com", "https://www.paypal.com"
    
    # Report violations if configured
    if ENV['CSP_REPORT_URI'].present?
      policy.report_uri ENV['CSP_REPORT_URI']
    end
  end

  # Session configuration with enhanced security
  config.session_store :cookie_store, 
    key: '_festival_planner_session',
    secure: true,
    httponly: true,
    same_site: :strict

  # Rate limiting middleware
  config.middleware.use Rack::Attack

  # Time zone configuration
  config.time_zone = 'Asia/Tokyo'

  # API rate limiting configuration
  config.api_rate_limit = {
    requests_per_minute: 100,
    requests_per_hour: 1000,
    requests_per_day: 10000
  }
end

# Initialize performance optimizations for production
Rails.application.config.after_initialize do
  if Rails.env.production?
    begin
      PerformanceOptimizationService.optimize_database_queries
      PerformanceOptimizationService.setup_caching_strategies
      PerformanceOptimizationService.optimize_assets
      PerformanceOptimizationService.monitor_performance
      PerformanceOptimizationService.warm_cache
      
      Rails.logger.info "Production optimizations initialized successfully"
    rescue => e
      Rails.logger.error "Failed to initialize production optimizations: #{e.message}"
    end
  end
end
