class JwtTokenService
  # JWT秘密鍵の設定
  JWT_SECRET = Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base

  # トークンの有効期限設定
  TOKEN_EXPIRATION = {
    access: 1.hour,
    refresh: 30.days,
    api: 1.year
  }.freeze

  # トークンタイプの定義
  TOKEN_TYPES = %w[access refresh api].freeze

  class << self
    # JWTトークンの生成
    def encode(payload, token_type: 'access')
      validate_token_type!(token_type)
      
      # 標準クレームの追加
      now = Time.current
      payload.merge!(
        iat: now.to_i,                                    # issued at
        exp: (now + TOKEN_EXPIRATION[token_type.to_sym]).to_i, # expiration
        jti: SecureRandom.uuid,                          # JWT ID
        iss: Rails.application.class.module_parent_name,  # issuer
        aud: determine_audience(token_type),             # audience
        typ: token_type                                  # token type
      )

      JWT.encode(payload, JWT_SECRET, 'HS256')
    end

    # JWTトークンの復号・検証
    def decode(token, token_type: nil)
      begin
        decoded = JWT.decode(token, JWT_SECRET, true, {
          algorithm: 'HS256',
          verify_iat: true,
          verify_exp: true,
          verify_iss: true,
          verify_aud: true,
          iss: Rails.application.class.module_parent_name,
          aud: token_type ? determine_audience(token_type) : nil
        })
        
        payload = decoded[0]
        
        # トークンタイプの検証
        if token_type && payload['typ'] != token_type
          raise JWT::InvalidPayload, "Invalid token type. Expected: #{token_type}, Got: #{payload['typ']}"
        end

        # カスタム検証
        validate_custom_claims(payload)
        
        payload
      rescue JWT::DecodeError => e
        Rails.logger.warn "JWT decode error: #{e.message}"
        nil
      rescue JWT::ExpiredSignature => e
        Rails.logger.info "JWT token expired: #{e.message}"
        nil
      rescue JWT::InvalidIssuerError, JWT::InvalidAudError => e
        Rails.logger.warn "JWT validation error: #{e.message}"
        nil
      end
    end

    # アクセストークンの生成
    def generate_access_token(user, scopes: [], request_info: {})
      payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        scopes: Array(scopes),
        permissions: user.api_permissions || {},
        request_ip: request_info[:ip],
        user_agent: request_info[:user_agent]&.truncate(200)
      }
      
      encode(payload, token_type: 'access')
    end

    # リフレッシュトークンの生成
    def generate_refresh_token(user, device_id: nil)
      payload = {
        user_id: user.id,
        device_id: device_id,
        token_family: SecureRandom.uuid # トークンファミリーでセッション管理
      }
      
      encode(payload, token_type: 'refresh')
    end

    # APIトークンの生成（長期利用）
    def generate_api_token(user, name: nil, scopes: [])
      payload = {
        user_id: user.id,
        email: user.email,
        token_name: name,
        scopes: Array(scopes),
        permissions: user.api_permissions || {}
      }
      
      encode(payload, token_type: 'api')
    end

    # トークンからユーザー情報を取得
    def user_from_token(token, token_type: nil)
      payload = decode(token, token_type: token_type)
      return nil unless payload

      user = User.find_by(id: payload['user_id'])
      return nil unless user&.active?

      # 追加セキュリティ検証
      if token_type == 'access'
        # IPアドレス検証（設定されている場合）
        if payload['request_ip'] && user.api_ip_whitelist.present?
          return nil unless user.api_ip_whitelist.include?(payload['request_ip'])
        end
      end

      user
    end

    # トークンの有効性確認
    def token_valid?(token, token_type: nil)
      payload = decode(token, token_type: token_type)
      payload.present?
    end

    # トークンからスコープを取得
    def token_scopes(token)
      payload = decode(token)
      return [] unless payload
      
      Array(payload['scopes'])
    end

    # リフレッシュトークンからアクセストークンを生成
    def refresh_access_token(refresh_token, request_info: {})
      payload = decode(refresh_token, token_type: 'refresh')
      return nil unless payload

      user = User.find_by(id: payload['user_id'])
      return nil unless user&.active?

      # 新しいアクセストークンを生成
      generate_access_token(user, request_info: request_info)
    end

    # トークンの取り消し（ブラックリスト機能）
    def revoke_token(token)
      payload = decode(token)
      return false unless payload

      # Redisまたはデータベースにブラックリストを保存
      Rails.cache.write(
        "revoked_token:#{payload['jti']}", 
        true, 
        expires_in: Time.at(payload['exp']) - Time.current
      )
      
      true
    end

    # トークンがブラックリストに含まれているかチェック
    def token_revoked?(token)
      payload = decode(token)
      return true unless payload

      Rails.cache.exist?("revoked_token:#{payload['jti']}")
    end

    private

    def validate_token_type!(token_type)
      unless TOKEN_TYPES.include?(token_type.to_s)
        raise ArgumentError, "Invalid token type: #{token_type}. Valid types: #{TOKEN_TYPES.join(', ')}"
      end
    end

    def determine_audience(token_type)
      case token_type.to_s
      when 'access'
        'festival-planner-web'
      when 'refresh'
        'festival-planner-auth'
      when 'api'
        'festival-planner-api'
      else
        'festival-planner'
      end
    end

    def validate_custom_claims(payload)
      # JTIの重複チェック（オプション）
      if Rails.cache.exist?("used_token:#{payload['jti']}")
        raise JWT::InvalidPayload, "Token already used (replay attack detection)"
      end

      # 必要に応じてJTIを記録（replay攻撃防止）
      if payload['typ'] == 'access'
        Rails.cache.write(
          "used_token:#{payload['jti']}", 
          true, 
          expires_in: TOKEN_EXPIRATION[:access]
        )
      end
    end
  end
end