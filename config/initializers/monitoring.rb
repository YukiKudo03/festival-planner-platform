# frozen_string_literal: true

# Application monitoring and metrics configuration
# Provides comprehensive monitoring for production deployment

if Rails.env.production?
  require 'prometheus/middleware/collector'
  require 'prometheus/middleware/exporter'
  
  # Prometheus metrics configuration
  Rails.application.middleware.use Prometheus::Middleware::Collector
  Rails.application.middleware.use Prometheus::Middleware::Exporter
  
  # Custom application metrics
  Rails.application.config.after_initialize do
    # User activity metrics
    ActiveSupport::Notifications.subscribe('user.login') do |name, start, finish, id, payload|
      Rails.logger.info "[METRICS] User login: #{payload[:user_id]}"
      $user_login_counter&.increment(labels: { 
        user_type: payload[:user_type] || 'unknown',
        success: payload[:success] || false
      })
    end
    
    # Festival creation metrics
    ActiveSupport::Notifications.subscribe('festival.created') do |name, start, finish, id, payload|
      Rails.logger.info "[METRICS] Festival created: #{payload[:festival_id]}"
      $festival_creation_counter&.increment(labels: {
        category: payload[:category] || 'unknown',
        organizer_type: payload[:organizer_type] || 'unknown'
      })
    end
    
    # Permit application metrics
    ActiveSupport::Notifications.subscribe('permit.submitted') do |name, start, finish, id, payload|
      Rails.logger.info "[METRICS] Permit submitted: #{payload[:application_id]}"
      $permit_submission_counter&.increment(labels: {
        permit_type: payload[:permit_type] || 'unknown',
        authority: payload[:authority] || 'unknown'
      })
    end
    
    # API response time tracking
    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, id, payload|
      if payload[:controller].include?('Api::')
        duration = finish - start
        $api_response_time_histogram&.observe(duration, labels: {
          controller: payload[:controller],
          action: payload[:action],
          status: payload[:status]
        })
      end
    end
    
    # Database query metrics
    ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
      duration = finish - start
      if duration > 0.1 # Log slow queries (> 100ms)
        Rails.logger.warn "[SLOW QUERY] #{duration}s: #{payload[:sql]}"
      end
      
      $db_query_duration_histogram&.observe(duration, labels: {
        operation: payload[:name] || 'unknown'
      })
    end
  end
end

# Health check endpoint configuration
# Note: Route definitions moved to config/routes.rb to avoid initialization conflicts

# Error tracking configuration
if Rails.env.production? && ENV['SENTRY_DSN'].present?
  require 'sentry-ruby'
  require 'sentry-rails'
  
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 0.1
    config.environment = Rails.env
    config.release = ENV['APP_VERSION'] || 'unknown'
    
    # Filter sensitive data
    config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
  end
end

# Logging configuration for production
if Rails.env.production?
  # Structured logging
  Rails.application.configure do
    config.log_formatter = proc do |severity, datetime, progname, msg|
      {
        timestamp: datetime.iso8601,
        level: severity,
        program: progname,
        message: msg,
        environment: Rails.env,
        version: ENV['APP_VERSION'] || 'unknown'
      }.to_json + "\n"
    end
    
    # Log level based on environment variable
    config.log_level = ENV['LOG_LEVEL']&.to_sym || :info
  end
  
  # Custom log tags for request tracing
  Rails.application.config.log_tags = [
    :request_id,
    -> request { "User:#{request.env['warden']&.user&.id || 'anonymous'}" },
    -> request { "IP:#{request.remote_ip}" }
  ]
end