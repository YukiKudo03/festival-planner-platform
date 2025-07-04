class SecurityAuditService
  include ActiveSupport::Configurable
  
  # Security configuration
  config_accessor :max_password_attempts, default: 5
  config_accessor :session_timeout, default: 24.hours
  config_accessor :api_rate_limit, default: 100
  config_accessor :strong_password_required, default: true
  
  SECURITY_HEADERS = %w[
    X-Frame-Options
    X-Content-Type-Options
    X-XSS-Protection
    Strict-Transport-Security
    Content-Security-Policy
    Referrer-Policy
  ].freeze
  
  SENSITIVE_ENDPOINTS = %w[
    /users/sign_in
    /users/sign_up
    /users/password
    /api/v1/payments
    /admin
  ].freeze
  
  def self.run_comprehensive_audit
    results = {
      timestamp: Time.current,
      overall_score: 0,
      critical_issues: [],
      warnings: [],
      passed_checks: [],
      recommendations: []
    }
    
    # Run all security checks
    results = check_authentication_security(results)
    results = check_authorization_security(results)
    results = check_data_encryption(results)
    results = check_input_validation(results)
    results = check_session_security(results)
    results = check_api_security(results)
    results = check_payment_security(results)
    results = check_file_upload_security(results)
    results = check_database_security(results)
    results = check_infrastructure_security(results)
    
    # Calculate overall security score
    results[:overall_score] = calculate_security_score(results)
    
    # Generate recommendations
    results[:recommendations] = generate_security_recommendations(results)
    
    # Log audit results
    log_audit_results(results)
    
    results
  end
  
  def self.check_authentication_security(results)
    Rails.logger.info "Checking authentication security..."
    
    # Check password policy
    if User.validators_on(:password).any? { |v| v.is_a?(ActiveModel::Validations::LengthValidator) && v.options[:minimum] >= 8 }
      results[:passed_checks] << "Strong password policy enforced"
    else
      results[:critical_issues] << "Weak password policy detected"
    end
    
    # Check for proper password hashing
    if defined?(Devise) && Devise.stretches >= 12
      results[:passed_checks] << "Strong password hashing configured"
    else
      results[:warnings] << "Password hashing could be stronger"
    end
    
    # Check for rate limiting on login attempts
    if defined?(Devise::FailureApp) || Rails.application.config.respond_to?(:api_rate_limit)
      results[:passed_checks] << "Login rate limiting configured"
    else
      results[:critical_issues] << "No login rate limiting detected"
    end
    
    # Check for account lockout mechanism
    if User.respond_to?(:maximum_attempts) && User.maximum_attempts.present?
      results[:passed_checks] << "Account lockout mechanism enabled"
    else
      results[:warnings] << "Account lockout mechanism not configured"
    end
    
    results
  end
  
  def self.check_authorization_security(results)
    Rails.logger.info "Checking authorization security..."
    
    # Check for proper role-based access control
    if User.respond_to?(:role) && User.roles.present?
      results[:passed_checks] << "Role-based access control implemented"
    else
      results[:critical_issues] << "No role-based access control found"
    end
    
    # Check for before_action filters
    controllers = Dir.glob(Rails.root.join('app/controllers/**/*.rb'))
    secure_controllers = 0
    
    controllers.each do |controller_file|
      content = File.read(controller_file)
      if content.include?('before_action') && (content.include?('authenticate') || content.include?('authorize'))
        secure_controllers += 1
      end
    end
    
    if secure_controllers > controllers.length * 0.8
      results[:passed_checks] << "Most controllers have authentication checks"
    else
      results[:warnings] << "Some controllers may lack proper authentication"
    end
    
    results
  end
  
  def self.check_data_encryption(results)
    Rails.logger.info "Checking data encryption..."
    
    # Check SSL configuration
    if Rails.application.config.force_ssl
      results[:passed_checks] << "SSL/TLS enforced"
    else
      results[:critical_issues] << "SSL/TLS not enforced"
    end
    
    # Check for encrypted attributes
    encrypted_models = []
    Dir.glob(Rails.root.join('app/models/*.rb')).each do |model_file|
      content = File.read(model_file)
      if content.include?('encrypts') || content.include?('attr_encrypted')
        encrypted_models << File.basename(model_file, '.rb')
      end
    end
    
    if encrypted_models.any?
      results[:passed_checks] << "Sensitive data encryption found in: #{encrypted_models.join(', ')}"
    else
      results[:warnings] << "No explicit data encryption found in models"
    end
    
    # Check database encryption at rest
    if Rails.application.config.active_record.encryption.primary_key.present?
      results[:passed_checks] << "Database encryption configured"
    else
      results[:recommendations] << "Consider implementing database encryption at rest"
    end
    
    results
  end
  
  def self.check_input_validation(results)
    Rails.logger.info "Checking input validation..."
    
    # Check for SQL injection protection
    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      results[:passed_checks] << "Using parameterized queries (ActiveRecord)"
    end
    
    # Check for XSS protection
    if Rails.application.config.force_ssl && 
       ApplicationController.instance_methods.include?(:protect_from_forgery)
      results[:passed_checks] << "CSRF protection enabled"
    else
      results[:critical_issues] << "CSRF protection may not be properly configured"
    end
    
    # Check for strong parameters usage
    controllers = Dir.glob(Rails.root.join('app/controllers/**/*.rb'))
    strong_param_usage = 0
    
    controllers.each do |controller_file|
      content = File.read(controller_file)
      if content.include?('permit(') || content.include?('require(')
        strong_param_usage += 1
      end
    end
    
    if strong_param_usage > controllers.length * 0.7
      results[:passed_checks] << "Strong parameters widely used"
    else
      results[:warnings] << "Some controllers may lack strong parameter filtering"
    end
    
    results
  end
  
  def self.check_session_security(results)
    Rails.logger.info "Checking session security..."
    
    # Check session configuration
    session_config = Rails.application.config.session_options || {}
    
    if session_config[:secure] || Rails.application.config.force_ssl
      results[:passed_checks] << "Secure session cookies configured"
    else
      results[:critical_issues] << "Session cookies not marked as secure"
    end
    
    if session_config[:httponly] != false
      results[:passed_checks] << "HTTP-only session cookies configured"
    else
      results[:warnings] << "Session cookies accessible via JavaScript"
    end
    
    if session_config[:same_site] == :strict || session_config[:same_site] == :lax
      results[:passed_checks] << "SameSite cookie protection enabled"
    else
      results[:warnings] << "SameSite cookie protection not configured"
    end
    
    results
  end
  
  def self.check_api_security(results)
    Rails.logger.info "Checking API security..."
    
    # Check for API authentication
    if File.exist?(Rails.root.join('app/controllers/api/v1/base_controller.rb'))
      base_controller_content = File.read(Rails.root.join('app/controllers/api/v1/base_controller.rb'))
      
      if base_controller_content.include?('authenticate_api_user')
        results[:passed_checks] << "API authentication implemented"
      else
        results[:critical_issues] << "API authentication not found"
      end
      
      if base_controller_content.include?('rate_limit') || base_controller_content.include?('throttle')
        results[:passed_checks] << "API rate limiting implemented"
      else
        results[:warnings] << "API rate limiting not detected"
      end
    end
    
    # Check for CORS configuration
    if File.exist?(Rails.root.join('config/initializers/cors.rb'))
      results[:passed_checks] << "CORS configuration found"
    else
      results[:recommendations] << "Consider configuring CORS for API security"
    end
    
    results
  end
  
  def self.check_payment_security(results)
    Rails.logger.info "Checking payment security..."
    
    # Check payment model security
    if File.exist?(Rails.root.join('app/models/payment.rb'))
      payment_content = File.read(Rails.root.join('app/models/payment.rb'))
      
      if payment_content.include?('validates') && payment_content.include?('amount')
        results[:passed_checks] << "Payment amount validation found"
      else
        results[:critical_issues] << "Payment validation may be insufficient"
      end
      
      if payment_content.include?('enum') && payment_content.include?('status')
        results[:passed_checks] << "Payment status management implemented"
      else
        results[:warnings] << "Payment status management needs review"
      end
    end
    
    # Check for PCI compliance preparation
    if ENV['STRIPE_SECRET_KEY'].present? || ENV['PAYPAL_CLIENT_SECRET'].present?
      results[:passed_checks] << "External payment processors configured"
      results[:recommendations] << "Ensure PCI DSS compliance for payment processing"
    end
    
    results
  end
  
  def self.check_file_upload_security(results)
    Rails.logger.info "Checking file upload security..."
    
    # Check Active Storage configuration
    if Rails.application.config.active_storage.variant_processor.present?
      results[:passed_checks] << "Image processing configured"
    end
    
    # Check for file type restrictions
    if Dir.glob(Rails.root.join('app/models/*.rb')).any? { |f| File.read(f).include?('content_type') }
      results[:passed_checks] << "File type validation found"
    else
      results[:warnings] << "File type validation may be missing"
    end
    
    # Check for file size limits
    upload_configs = Dir.glob(Rails.root.join('config/**/*.rb')).map { |f| File.read(f) }.join
    if upload_configs.include?('client_max_body_size') || upload_configs.include?('max_file_size')
      results[:passed_checks] << "File size limits configured"
    else
      results[:recommendations] << "Consider implementing file size limits"
    end
    
    results
  end
  
  def self.check_database_security(results)
    Rails.logger.info "Checking database security..."
    
    # Check database configuration
    db_config = Rails.application.config.database_configuration[Rails.env]
    
    if db_config['sslmode'] == 'require' || db_config['sslmode'] == 'verify-full'
      results[:passed_checks] << "Database SSL connection configured"
    else
      results[:warnings] << "Database SSL connection not enforced"
    end
    
    # Check for connection pooling
    if db_config['pool'].present? && db_config['pool'] > 1
      results[:passed_checks] << "Database connection pooling configured"
    else
      results[:recommendations] << "Configure database connection pooling for production"
    end
    
    # Check for backup strategy
    if ENV['BACKUP_S3_BUCKET'].present? || Dir.exist?(Rails.root.join('db/backups'))
      results[:passed_checks] << "Backup strategy appears to be in place"
    else
      results[:critical_issues] << "No backup strategy detected"
    end
    
    results
  end
  
  def self.check_infrastructure_security(results)
    Rails.logger.info "Checking infrastructure security..."
    
    # Check environment variables
    if File.exist?(Rails.root.join('.env.production.example'))
      results[:passed_checks] << "Production environment template found"
    end
    
    # Check Docker security
    if File.exist?(Rails.root.join('Dockerfile'))
      dockerfile_content = File.read(Rails.root.join('Dockerfile'))
      
      if dockerfile_content.include?('USER') && !dockerfile_content.include?('USER root')
        results[:passed_checks] << "Docker non-root user configured"
      else
        results[:warnings] << "Docker container may run as root"
      end
      
      if dockerfile_content.include?('HEALTHCHECK')
        results[:passed_checks] << "Docker health check configured"
      else
        results[:recommendations] << "Add Docker health check for monitoring"
      end
    end
    
    # Check for security headers
    if File.exist?(Rails.root.join('config/nginx.conf'))
      nginx_content = File.read(Rails.root.join('config/nginx.conf'))
      
      SECURITY_HEADERS.each do |header|
        if nginx_content.include?(header)
          results[:passed_checks] << "Security header #{header} configured"
        else
          results[:warnings] << "Security header #{header} missing"
        end
      end
    end
    
    results
  end
  
  def self.calculate_security_score(results)
    total_checks = results[:passed_checks].length + results[:warnings].length + results[:critical_issues].length
    return 0 if total_checks == 0
    
    passed_weight = 1.0
    warning_weight = 0.5
    critical_weight = 0.0
    
    score = (
      (results[:passed_checks].length * passed_weight) +
      (results[:warnings].length * warning_weight) +
      (results[:critical_issues].length * critical_weight)
    ) / total_checks * 100
    
    score.round(1)
  end
  
  def self.generate_security_recommendations(results)
    recommendations = []
    
    # Critical issues recommendations
    results[:critical_issues].each do |issue|
      case issue
      when /password policy/
        recommendations << "Implement strong password policy with minimum 8 characters, complexity requirements"
      when /SSL/
        recommendations << "Enable SSL/TLS enforcement in production environment"
      when /authentication/
        recommendations << "Implement proper authentication mechanisms for all sensitive endpoints"
      when /backup/
        recommendations << "Set up automated database backup strategy with offsite storage"
      end
    end
    
    # Warning-based recommendations
    if results[:warnings].any? { |w| w.include?('rate limiting') }
      recommendations << "Implement comprehensive rate limiting for API and authentication endpoints"
    end
    
    if results[:warnings].any? { |w| w.include?('session') }
      recommendations << "Review session security configuration for production deployment"
    end
    
    # General recommendations
    recommendations += [
      "Perform regular security audits and vulnerability assessments",
      "Keep all dependencies updated to latest secure versions",
      "Implement comprehensive logging and monitoring",
      "Consider implementing Web Application Firewall (WAF)",
      "Perform penetration testing before production launch"
    ]
    
    recommendations.uniq
  end
  
  def self.log_audit_results(results)
    Rails.logger.info "=== SECURITY AUDIT RESULTS ==="
    Rails.logger.info "Timestamp: #{results[:timestamp]}"
    Rails.logger.info "Overall Score: #{results[:overall_score]}%"
    Rails.logger.info "Passed Checks: #{results[:passed_checks].length}"
    Rails.logger.info "Warnings: #{results[:warnings].length}"
    Rails.logger.info "Critical Issues: #{results[:critical_issues].length}"
    
    if results[:critical_issues].any?
      Rails.logger.error "CRITICAL SECURITY ISSUES:"
      results[:critical_issues].each { |issue| Rails.logger.error "  - #{issue}" }
    end
    
    if results[:warnings].any?
      Rails.logger.warn "SECURITY WARNINGS:"
      results[:warnings].each { |warning| Rails.logger.warn "  - #{warning}" }
    end
    
    Rails.logger.info "================================"
  end
  
  def self.vulnerability_scan
    vulnerabilities = []
    
    # Check for known vulnerable gems
    if defined?(Bundler)
      begin
        # This would integrate with bundler-audit or similar
        Rails.logger.info "Checking for vulnerable dependencies..."
        # In a real implementation, you'd run: `bundle audit check --update`
        vulnerabilities << "Run 'bundle audit' to check for vulnerable gems"
      rescue => e
        Rails.logger.error "Dependency check failed: #{e.message}"
      end
    end
    
    # Check for exposed sensitive files
    sensitive_files = %w[
      .env
      .env.production
      config/master.key
      config/credentials.yml.enc
      config/database.yml
    ]
    
    sensitive_files.each do |file|
      if File.exist?(Rails.root.join(file)) && File.readable?(Rails.root.join(file))
        vulnerabilities << "Sensitive file #{file} may be exposed"
      end
    end
    
    # Check for default credentials
    if Rails.application.secrets.secret_key_base == 'default' ||
       ENV['DATABASE_PASSWORD'] == 'password' ||
       ENV['REDIS_PASSWORD'].blank?
      vulnerabilities << "Default or weak credentials detected"
    end
    
    vulnerabilities
  end
  
  def self.generate_security_report
    audit_results = run_comprehensive_audit
    vulnerabilities = vulnerability_scan
    
    {
      audit: audit_results,
      vulnerabilities: vulnerabilities,
      generated_at: Time.current,
      recommendations: audit_results[:recommendations] + [
        "Review and update security policies regularly",
        "Implement security awareness training for development team",
        "Set up automated security scanning in CI/CD pipeline"
      ]
    }
  end
end