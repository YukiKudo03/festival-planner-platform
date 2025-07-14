class ApiRequest < ApplicationRecord
  belongs_to :api_key
  belongs_to :user, optional: true

  validates :endpoint, presence: true
  validates :method, presence: true, inclusion: { in: %w[GET POST PUT PATCH DELETE] }
  validates :ip_address, presence: true
  validates :response_status, presence: true, numericality: { in: 100..599 }

  scope :successful, -> { where("response_status < 400") }
  scope :failed, -> { where("response_status >= 400") }
  scope :recent, ->(duration = 1.hour) { where("created_at > ?", duration.ago) }
  scope :by_endpoint, ->(endpoint) { where(endpoint: endpoint) }
  scope :by_method, ->(method) { where(method: method.upcase) }

  # 地理的情報の取得（オプション）
  def geographic_info
    return @geographic_info if defined?(@geographic_info)

    @geographic_info = Rails.cache.fetch("geo_info:#{ip_address}", expires_in: 1.day) do
      # 実際の実装では GeoIP2 gem などを使用
      {
        country: "Unknown",
        region: "Unknown",
        city: "Unknown"
      }
    end
  end

  def success?
    response_status < 400
  end

  def error?
    response_status >= 400
  end

  def client_error?
    response_status >= 400 && response_status < 500
  end

  def server_error?
    response_status >= 500
  end

  # セキュリティ関連の分析
  def suspicious?
    # 疑わしいパターンの検出
    suspicious_patterns = [
      endpoint.include?(".."),           # パストラバーサル
      endpoint.include?("<script"),      # XSS試行
      endpoint.include?("SELECT"),       # SQL注入試行
      endpoint.include?("UNION"),        # SQL注入試行
      user_agent&.include?("bot"),       # ボットアクセス
      user_agent&.include?("crawler"),   # クローラー
      response_status == 401,            # 認証エラー
      response_status == 403             # 認可エラー
    ]

    suspicious_patterns.any?
  end

  # レスポンス時間の分析用
  def slow_request?
    response_time_ms.present? && response_time_ms > 5000 # 5秒以上
  end

  class << self
    # 統計情報の生成
    def generate_stats(period: 1.day)
      requests = where("created_at > ?", period.ago)

      {
        total_requests: requests.count,
        successful_requests: requests.successful.count,
        failed_requests: requests.failed.count,
        success_rate: calculate_success_rate(requests),
        avg_response_time: calculate_avg_response_time(requests),
        top_endpoints: requests.group(:endpoint).order("count_all DESC").limit(10).count,
        top_user_agents: requests.group(:user_agent).order("count_all DESC").limit(5).count,
        status_code_distribution: requests.group(:response_status).count,
        requests_by_hour: requests.group_by_hour(:created_at).count
      }
    end

    # 異常検知
    def detect_anomalies(period: 1.hour)
      recent_requests = where("created_at > ?", period.ago)
      anomalies = []

      # 1. 急激なリクエスト増加
      normal_rate = where("created_at BETWEEN ? AND ?", 2.days.ago, 1.day.ago).count / 24.0
      current_rate = recent_requests.count

      if current_rate > normal_rate * 3
        anomalies << {
          type: "traffic_spike",
          severity: "high",
          description: "Request rate #{current_rate} is 3x normal (#{normal_rate.round(2)})"
        }
      end

      # 2. 異常なエラー率
      error_rate = recent_requests.failed.count.to_f / [ recent_requests.count, 1 ].max
      if error_rate > 0.3
        anomalies << {
          type: "high_error_rate",
          severity: "medium",
          description: "Error rate #{(error_rate * 100).round(1)}% exceeds threshold"
        }
      end

      # 3. 疑わしいリクエストパターン
      suspicious_count = recent_requests.select(&:suspicious?).count
      if suspicious_count > recent_requests.count * 0.1
        anomalies << {
          type: "suspicious_activity",
          severity: "high",
          description: "#{suspicious_count} suspicious requests detected"
        }
      end

      # 4. 新しいIPからの大量アクセス
      ip_counts = recent_requests.group(:ip_address).count
      new_high_volume_ips = ip_counts.select { |ip, count| count > 100 && !known_ip?(ip) }

      if new_high_volume_ips.any?
        anomalies << {
          type: "unknown_high_volume_ip",
          severity: "medium",
          description: "High volume from new IPs: #{new_high_volume_ips.keys.join(', ')}"
        }
      end

      anomalies
    end

    # セキュリティレポートの生成
    def security_report(period: 1.day)
      requests = where("created_at > ?", period.ago)

      {
        period: period,
        total_requests: requests.count,
        suspicious_requests: requests.select(&:suspicious?).count,
        failed_auth_attempts: requests.where(response_status: 401).count,
        blocked_requests: requests.where(response_status: 403).count,
        unique_ips: requests.distinct.count(:ip_address),
        top_error_endpoints: requests.failed.group(:endpoint).order("count_all DESC").limit(10).count,
        geographic_distribution: calculate_geographic_distribution(requests),
        anomalies: detect_anomalies(period: period)
      }
    end

    private

    def calculate_success_rate(requests)
      return 100.0 if requests.count.zero?
      (requests.successful.count.to_f / requests.count * 100).round(2)
    end

    def calculate_avg_response_time(requests)
      times = requests.where.not(response_time_ms: nil).pluck(:response_time_ms)
      return 0 if times.empty?
      (times.sum.to_f / times.size).round(2)
    end

    def known_ip?(ip_address)
      # 既知のIPかどうかを判定（過去30日間にリクエストがあったか）
      exists?(ip_address: ip_address, created_at: 30.days.ago..1.day.ago)
    end

    def calculate_geographic_distribution(requests)
      # 地理的分布の計算（実装は簡略化）
      requests.group(:ip_address).count.transform_values { |_| "Unknown" }
    end
  end
end
