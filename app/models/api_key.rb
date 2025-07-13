class ApiKey < ApplicationRecord
  belongs_to :user
  has_many :api_requests, dependent: :destroy

  # API キーのスコープ定義
  SCOPES = %w[
    festivals:read festivals:write festivals:delete
    tasks:read tasks:write tasks:delete  
    budgets:read budgets:write
    vendors:read vendors:write
    payments:read payments:write
    analytics:read
    admin:read admin:write
  ].freeze

  # API キーの種類
  KEY_TYPES = %w[personal application webhook].freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :key_type, inclusion: { in: KEY_TYPES }
  validates :api_key, presence: true, uniqueness: true
  validates :scopes, presence: true
  
  validate :validate_scopes
  validate :validate_ip_whitelist
  validate :validate_user_permissions

  before_validation :generate_api_key, on: :create
  before_validation :set_defaults

  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :personal, -> { where(key_type: 'personal') }
  scope :application, -> { where(key_type: 'application') }
  scope :webhook, -> { where(key_type: 'webhook') }

  # スコープをJSON配列として保存
  serialize :scopes, coder: JSON
  serialize :ip_whitelist, coder: JSON
  serialize :rate_limits, coder: JSON
  serialize :usage_stats, coder: JSON

  def active?
    active && !expired?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def can_access_scope?(scope)
    return false unless active?
    scopes.include?(scope.to_s)
  end

  def can_access_ip?(ip_address)
    return true if ip_whitelist.blank?
    ip_whitelist.include?(ip_address)
  end

  def within_rate_limit?(window = 1.hour)
    return true unless rate_limits.present?
    
    current_hour_requests = api_requests
                           .where('created_at > ?', window.ago)
                           .count
    
    limit = rate_limits['requests_per_hour'] || 1000
    current_hour_requests < limit
  end

  def record_request!(request_info = {})
    increment!(:request_count)
    update!(last_used_at: Time.current)
    
    # 使用統計の更新
    update_usage_stats!
    
    # リクエスト履歴の記録（詳細ログが必要な場合）
    if should_log_request?
      api_requests.create!(
        endpoint: request_info[:endpoint],
        method: request_info[:method],
        ip_address: request_info[:ip],
        user_agent: request_info[:user_agent],
        response_status: request_info[:status],
        created_at: Time.current
      )
    end
  end

  def revoke!
    update!(active: false, revoked_at: Time.current)
    
    # JWT ブラックリストに追加
    Rails.cache.write(
      "revoked_api_key:#{api_key}",
      true,
      expires_in: 1.year
    )
  end

  def revoked?
    !active? || Rails.cache.exist?("revoked_api_key:#{api_key}")
  end

  # 使用統計のサマリー
  def usage_summary
    {
      total_requests: request_count,
      last_used: last_used_at,
      daily_average: calculate_daily_average,
      top_endpoints: calculate_top_endpoints,
      success_rate: calculate_success_rate
    }
  end

  # セキュリティアラートが必要かチェック
  def security_alert_needed?
    return false unless active?
    
    # 異常な使用パターンの検出
    recent_requests = api_requests.where('created_at > ?', 1.hour.ago)
    
    # 急激な使用量増加
    if recent_requests.count > (rate_limits['requests_per_hour'] || 1000) * 0.8
      return true
    end
    
    # 複数IPからのアクセス（personal keyの場合）
    if key_type == 'personal' && recent_requests.distinct.count(:ip_address) > 3
      return true
    end
    
    # 異常なエラー率
    error_rate = recent_requests.where('response_status >= 400').count.to_f / 
                 [recent_requests.count, 1].max
    
    error_rate > 0.5
  end

  private

  def generate_api_key
    loop do
      self.api_key = "fp_#{key_type[0]}#{SecureRandom.hex(20)}"
      break unless self.class.exists?(api_key: api_key)
    end
  end

  def set_defaults
    self.active = true if active.nil?
    self.scopes ||= []
    self.ip_whitelist ||= []
    self.rate_limits ||= default_rate_limits
    self.usage_stats ||= {}
    self.expires_at ||= 1.year.from_now if key_type != 'personal'
  end

  def default_rate_limits
    case key_type
    when 'personal'
      { 'requests_per_hour' => 1000, 'requests_per_day' => 10000 }
    when 'application'
      { 'requests_per_hour' => 5000, 'requests_per_day' => 100000 }
    when 'webhook'
      { 'requests_per_hour' => 100, 'requests_per_day' => 1000 }
    else
      { 'requests_per_hour' => 1000, 'requests_per_day' => 10000 }
    end
  end

  def validate_scopes
    return if scopes.blank?
    
    invalid_scopes = scopes - SCOPES
    if invalid_scopes.any?
      errors.add(:scopes, "Invalid scopes: #{invalid_scopes.join(', ')}")
    end
  end

  def validate_ip_whitelist
    return if ip_whitelist.blank?
    
    ip_whitelist.each do |ip|
      begin
        IPAddr.new(ip)
      rescue IPAddr::InvalidAddressError
        errors.add(:ip_whitelist, "Invalid IP address: #{ip}")
        break
      end
    end
  end

  def validate_user_permissions
    return unless user
    
    # ユーザーが持っていないスコープは使用できない
    user_scopes = user.available_api_scopes
    unauthorized_scopes = scopes - user_scopes
    
    if unauthorized_scopes.any?
      errors.add(:scopes, "User doesn't have permission for: #{unauthorized_scopes.join(', ')}")
    end
  end

  def should_log_request?
    # 詳細ログが必要なケース
    key_type == 'application' || 
    security_alert_needed? ||
    Rails.env.development?
  end

  def update_usage_stats!
    today = Date.current.to_s
    self.usage_stats ||= {}
    self.usage_stats['daily'] ||= {}
    self.usage_stats['daily'][today] = (self.usage_stats['daily'][today] || 0) + 1
    
    # 古いデータのクリーンアップ（30日以上前）
    cutoff_date = 30.days.ago.to_date.to_s
    self.usage_stats['daily'] = self.usage_stats['daily'].select { |date, _| date >= cutoff_date }
    
    save!
  end

  def calculate_daily_average
    return 0 unless usage_stats['daily'].present?
    
    usage_stats['daily'].values.sum.to_f / usage_stats['daily'].size
  end

  def calculate_top_endpoints
    api_requests
      .where('created_at > ?', 30.days.ago)
      .group(:endpoint)
      .order('count_all DESC')
      .limit(5)
      .count
  end

  def calculate_success_rate
    total = api_requests.where('created_at > ?', 30.days.ago).count
    return 100.0 if total.zero?
    
    success = api_requests
             .where('created_at > ? AND response_status < 400', 30.days.ago)
             .count
             
    (success.to_f / total * 100).round(2)
  end
end