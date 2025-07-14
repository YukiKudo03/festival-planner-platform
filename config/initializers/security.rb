# セキュリティ設定の初期化

Rails.application.configure do
  # X-Frame-Options ヘッダー
  config.force_ssl = Rails.env.production?

  # セキュリティ関連のヘッダー設定
  config.middleware.insert_before ActionDispatch::Static, Rack::Attack if defined?(Rack::Attack)

  # セキュリティヘッダーミドルウェア
  config.middleware.use Rack::Protection::Base
  config.middleware.use Rack::Protection::EscapedParams
  config.middleware.use Rack::Protection::JsonCsrf
  config.middleware.use Rack::Protection::RemoteReferrer
  config.middleware.use Rack::Protection::SessionHijacking
  config.middleware.use Rack::Protection::XSSHeader
end

# セキュアヘッダー設定
if Rails.env.production?
  Rails.application.config.middleware.insert_before ActionDispatch::Static, "SecureHeaders::Middleware" do
    SecureHeaders::Configuration.default do |config|
      config.x_frame_options = "DENY"
      config.x_content_type_options = "nosniff"
      config.x_xss_protection = "1; mode=block"
      config.x_download_options = "noopen"
      config.x_permitted_cross_domain_policies = "none"
      config.referrer_policy = %w[origin-when-cross-origin strict-origin-when-cross-origin]

      # HTTPS Strict Transport Security
      config.hsts = {
        max_age: 31_536_000, # 1 year
        include_subdomains: true,
        preload: true
      }

      # Public Key Pinning (本番環境でのみ有効化を推奨)
      config.hpkp = {
        max_age: 60.days.to_i,
        include_subdomains: true,
        report_uri: "https://your-report-uri.com/r/d/hpkp/enforce",
        pins: [
          { sha256: "base64+primary+pin" },
          { sha256: "base64+backup+pin" }
        ]
      } if ENV["ENABLE_HPKP"] == "true"
    end
  end
end

# Rate Limiting 設定
if defined?(Rack::Attack)
  # ログイン試行回数制限
  Rack::Attack.throttle("login/email", limit: 5, period: 60.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params["user"]["email"].presence
    end
  end

  # API呼び出し制限
  Rack::Attack.throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # 一般リクエスト制限
  Rack::Attack.throttle("req/ip", limit: 300, period: 5.minutes, &:ip)

  # 悪意のあるリクエストブロック
  Rack::Attack.blocklist("block script kiddies") do |req|
    # SQLインジェクション試行をブロック
    req.query_string =~ /\bunion\b.*\bselect\b/i ||
    req.query_string =~ /\bselect\b.*\bfrom\b/i ||
    req.query_string =~ /\bdrop\b.*\btable\b/i ||
    req.query_string.include?("<script") ||
    req.query_string.include?("javascript:")
  end

  # 管理者エリアの保護
  Rack::Attack.throttle("admin/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/admin")
  end
end

# データサニタイゼーション
ActionController::Base.class_eval do
  private

  def sanitize_params
    params.each do |key, value|
      if value.is_a?(String)
        # XSS攻撃を防ぐためのサニタイゼーション
        params[key] = ActionController::Base.helpers.sanitize(value, tags: [])
      end
    end
  end
end

# CSRFトークン設定強化
Rails.application.configure do
  config.force_ssl = Rails.env.production?

  # セッションハイジャック対策
  config.session_store :cookie_store,
    key: "_festival_planner_session",
    secure: Rails.env.production?,
    httponly: true,
    same_site: :strict,
    expires_after: 24.hours
end

# セキュリティ関連ログ設定
if Rails.env.production?
  Rails.logger.info "Security middleware initialized for production environment"
  Rails.logger.info "HTTPS enforcement: #{Rails.application.config.force_ssl}"
  Rails.logger.info "Secure cookies: #{Rails.application.config.ssl_options[:secure_cookies]}"
end
