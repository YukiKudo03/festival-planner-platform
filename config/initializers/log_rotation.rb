# frozen_string_literal: true

# Log rotation configuration for Festival Planner Platform
# Prevents log files from growing too large in development and test environments

if Rails.env.development? || Rails.env.test?
  require "logger"

  # Configure log rotation for development environment
  if Rails.env.development?
    # Rotate logs when they reach 10MB, keep 3 old files
    Rails.application.configure do
      config.logger = Logger.new(
        Rails.root.join("log", "development.log"),
        3,                    # Keep 3 old files
        10 * 1024 * 1024     # 10MB per file
      )
      config.logger.formatter = Rails.application.config.log_formatter if Rails.application.config.log_formatter
    end
  end

  # Configure log rotation for test environment
  if Rails.env.test?
    # Rotate logs when they reach 5MB, keep 2 old files
    Rails.application.configure do
      config.logger = Logger.new(
        Rails.root.join("log", "test.log"),
        2,                    # Keep 2 old files
        5 * 1024 * 1024      # 5MB per file
      )
      config.logger.formatter = Rails.application.config.log_formatter if Rails.application.config.log_formatter
    end
  end
end

# For production, log rotation is typically handled by logrotate or container orchestration
# See docker-compose.yml and deployment configuration for production log management
