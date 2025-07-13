require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FestivalPlannerPlatform
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Security configurations
    config.force_ssl = false # Set to true in production
    config.session_store :cookie_store, 
      key: '_festival_planner_session', 
      secure: Rails.env.production?,
      httponly: true,
      same_site: :strict
    
    # セキュリティヘッダー設定
    config.force_ssl = Rails.env.production?
    config.ssl_options = {
      hsts: { expires: 1.year, subdomains: true },
      secure_cookies: Rails.env.production?
    }
    
    # Content Security Policy
    config.content_security_policy do |policy|
      policy.default_src :self, :https
      policy.font_src    :self, :https, :data
      policy.img_src     :self, :https, :data, 'blob:'
      policy.object_src  :none
      policy.script_src  :self, :https, :unsafe_inline
      policy.style_src   :self, :https, :unsafe_inline
      policy.connect_src :self, :https, 'ws:', 'wss:'
      
      # フォームから画像をアップロードする際のリポート
      policy.report_uri '/csp_reports' if Rails.env.production?
    end
    
    # Feature Policy / Permissions Policy
    config.permissions_policy do |policy|
      policy.camera      :none
      policy.microphone  :none
      policy.geolocation :self
      policy.autoplay    :none
    end

    # Background job configuration
    config.active_job.queue_adapter = :solid_queue

    # TIME zone configuration
    config.time_zone = 'Asia/Tokyo'

    # LINE integration configuration
    config.line_integration = {
      webhook_timeout: 10.seconds,
      max_retry_attempts: 3,
      rate_limit_per_minute: 60
    }
  end
end
