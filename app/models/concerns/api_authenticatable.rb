module ApiAuthenticatable
  extend ActiveSupport::Concern
  
  included do
    before_create :generate_api_token
    
    scope :with_api_access, -> { where.not(api_token: nil) }
  end
  
  def generate_api_token!
    self.api_token = generate_unique_token
    self.api_token_expires_at = 1.year.from_now
    save!
  end
  
  def regenerate_api_token!
    generate_api_token!
  end
  
  def revoke_api_token!
    self.api_token = nil
    self.api_token_expires_at = nil
    save!
  end
  
  def api_token_valid?
    api_token.present? && 
    api_token_expires_at.present? && 
    api_token_expires_at > Time.current
  end
  
  def api_token_expired?
    !api_token_valid?
  end
  
  def can_create_festivals?
    admin? || committee_member? || api_permissions&.dig('create_festivals') == true
  end
  
  def can_access_analytics?
    admin? || committee_member? || api_permissions&.dig('access_analytics') == true
  end
  
  def can_export_data?
    admin? || committee_member? || api_permissions&.dig('export_data') == true
  end
  
  def api_rate_limit
    case role
    when 'admin', 'system_admin'
      1000 # requests per minute
    when 'committee_member'
      500
    else
      100
    end
  end
  
  def api_access_log
    {
      last_access: last_api_access_at,
      total_requests: api_request_count || 0,
      token_expires: api_token_expires_at,
      permissions: api_permissions || {}
    }
  end
  
  def increment_api_request_count!
    increment(:api_request_count)
    self.last_api_access_at = Time.current
    save!
  end
  
  def api_usage_stats(period = 30.days)
    {
      period: period,
      total_requests: api_request_count || 0,
      average_daily_requests: ((api_request_count || 0) / period.to_i.days).round(2),
      last_access: last_api_access_at,
      token_status: api_token_valid? ? 'valid' : 'expired'
    }
  end
  
  private
  
  def generate_api_token
    self.api_token = generate_unique_token
    self.api_token_expires_at = 1.year.from_now
  end
  
  def generate_unique_token
    loop do
      token = SecureRandom.hex(32)
      break token unless User.exists?(api_token: token)
    end
  end
end