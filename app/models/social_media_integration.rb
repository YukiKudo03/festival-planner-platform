class SocialMediaIntegration < ApplicationRecord
  belongs_to :user
  belongs_to :festival, optional: true

  validates :provider, presence: true, inclusion: { in: %w[facebook twitter instagram] }
  validates :name, presence: true
  validates :account_id, presence: true

  encrypts :access_token
  encrypts :access_token_secret
  encrypts :refresh_token

  scope :active, -> { where(active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }

  enum posting_schedule: {
    immediate: 0,
    scheduled: 1,
    approval_required: 2
  }

  enum status: {
    connected: 0,
    disconnected: 1,
    error: 2,
    expired: 3,
    pending_approval: 4
  }

  before_create :set_defaults
  after_update :schedule_posting, if: :saved_change_to_active?

  def facebook?
    provider == "facebook"
  end

  def twitter?
    provider == "twitter"
  end

  def instagram?
    provider == "instagram"
  end

  def posting_enabled?
    active? && connected? && access_token.present?
  end

  def token_expired?
    return false unless expires_at.present?
    expires_at < Time.current
  end

  def refresh_access_token!
    case provider
    when "facebook"
      refresh_facebook_token!
    when "twitter"
      # Twitter API v2 uses OAuth 2.0 with refresh tokens
      refresh_twitter_token!
    when "instagram"
      refresh_instagram_token!
    else
      false
    end
  end

  def social_service
    @social_service ||= case provider
    when "facebook"
                         FacebookService.new(self)
    when "twitter"
                         TwitterService.new(self)
    when "instagram"
                         InstagramService.new(self)
    end
  end

  def post_content!(content, options = {})
    return false unless posting_enabled?

    begin
      case posting_schedule
      when "immediate"
        result = social_service.post_content(content, options)
        log_post_result(result)
        result[:success]
      when "scheduled"
        schedule_post(content, options)
        true
      when "approval_required"
        create_pending_post(content, options)
        true
      end
    rescue => error
      Rails.logger.error "Social media posting failed for #{id}: #{error.message}"
      update!(last_post_error: error.message)
      false
    end
  end

  def generate_festival_content(festival, content_type = "announcement")
    case content_type
    when "announcement"
      generate_announcement_content(festival)
    when "countdown"
      generate_countdown_content(festival)
    when "behind_scenes"
      generate_behind_scenes_content(festival)
    when "completion"
      generate_completion_content(festival)
    else
      generate_default_content(festival)
    end
  end

  def hashtag_suggestions(festival)
    base_tags = [ "#祭り", "#イベント", "#地域活性化", "#フェスティバル" ]

    # Add location-based hashtags
    location_tags = extract_location_hashtags(festival.location) if festival.location

    # Add festival-specific hashtags
    festival_tags = [
      "##{festival.name.gsub(/\s+/, '')}",
      "##{festival.start_date&.strftime('%Y年%m月')}"
    ]

    # Add category-based hashtags
    category_tags = case festival.category
    when "music"
                     [ "#音楽祭", "#ライブ", "#コンサート" ]
    when "food"
                     [ "#グルメ", "#食べ歩き", "#フードフェス" ]
    when "art"
                     [ "#アート", "#芸術祭", "#展示会" ]
    when "cultural"
                     [ "#文化祭", "#伝統", "#文化" ]
    else
                     [ "#イベント" ]
    end

    (base_tags + location_tags.to_a + festival_tags + category_tags).uniq
  end

  def analytics_summary
    {
      total_posts: social_media_posts.count,
      successful_posts: social_media_posts.where(status: "published").count,
      failed_posts: social_media_posts.where(status: "failed").count,
      pending_posts: social_media_posts.where(status: "pending").count,
      total_engagement: social_media_posts.sum(:engagement_count),
      average_engagement: social_media_posts.average(:engagement_count)&.round(2) || 0,
      last_post_date: social_media_posts.order(:created_at).last&.created_at,
      most_engaged_post: social_media_posts.order(:engagement_count).last
    }
  end

  private

  def set_defaults
    self.active ||= true
    self.status ||= :connected
    self.posting_schedule ||= :approval_required
    self.auto_hashtags ||= true
  end

  def schedule_posting
    return unless active?

    SocialMediaPostingJob.perform_later(id)
  end

  def schedule_post(content, options)
    scheduled_time = options[:scheduled_time] || 1.hour.from_now

    SocialMediaScheduledPostJob.perform_at(scheduled_time, id, content, options)
  end

  def create_pending_post(content, options)
    SocialMediaPost.create!(
      social_media_integration: self,
      content: content,
      options: options,
      status: "pending_approval",
      scheduled_time: options[:scheduled_time]
    )
  end

  def log_post_result(result)
    if result[:success]
      update!(
        last_posted_at: Time.current,
        last_post_error: nil,
        post_count: post_count + 1
      )
    else
      update!(last_post_error: result[:error])
    end
  end

  def generate_announcement_content(festival)
    templates = [
      "🎉 #{festival.name}開催決定！\n#{festival.start_date&.strftime('%Y年%m月%d日')}#{festival.location ? "に#{festival.location}で" : ""}開催予定です。\n詳細はもうすぐ発表します！お楽しみに✨",

      "📅 #{festival.name}の詳細が決まりました！\n📍 会場: #{festival.location}\n📆 日程: #{festival.start_date&.strftime('%Y年%m月%d日')}#{festival.end_date ? " - #{festival.end_date.strftime('%m月%d日')}" : ""}\n\n準備着々と進行中です！",

      "🌟 #{festival.name}まで#{days_until_festival(festival)}日！\n地域の皆様と一緒に素晴らしいイベントを作り上げています。\n当日をお楽しみに！"
    ]

    templates.sample
  end

  def generate_countdown_content(festival)
    days_left = days_until_festival(festival)

    if days_left > 0
      "⏰ #{festival.name}まであと#{days_left}日！\n\n#{countdown_message(days_left)}\n\n#{festival.location}でお待ちしています🎪"
    else
      "🎉 本日#{festival.name}開催！\n会場でお待ちしています！\n\n#{festival.location}で素晴らしい一日を過ごしましょう✨"
    end
  end

  def generate_behind_scenes_content(festival)
    [
      "🔧 #{festival.name}の準備風景をちょっとだけお見せします！\nスタッフ一同、心を込めて準備中です💪",

      "👥 #{festival.name}の実行委員会ミーティング！\n皆さんに楽しんでいただけるよう、細部まで検討中です📝",

      "📦 #{festival.name}の設営準備が始まりました！\n当日の素晴らしい体験のため、今日も頑張っています🏗️"
    ].sample
  end

  def generate_completion_content(festival)
    "✨ #{festival.name}、無事に終了いたしました！\n\nご来場いただいた皆様、ご協力いただいた関係者の皆様、本当にありがとうございました🙏\n\n来年もお楽しみに！"
  end

  def generate_default_content(festival)
    "🎪 #{festival.name}\n#{festival.description&.slice(0, 100)}#{festival.description&.length.to_i > 100 ? '...' : ''}"
  end

  def days_until_festival(festival)
    return 0 unless festival.start_date

    (festival.start_date - Date.current).to_i
  end

  def countdown_message(days_left)
    case days_left
    when 30..Float::INFINITY
      "まだまだ準備期間！着々と進めています"
    when 14..29
      "準備もいよいよ大詰め！"
    when 7..13
      "最終準備に入りました！"
    when 1..6
      "いよいよ間近！最後の仕上げをしています"
    else
      "ついに当日です！"
    end
  end

  def extract_location_hashtags(location)
    # Simple location hashtag extraction
    # This could be enhanced with a more sophisticated location parser
    location_parts = location.split(/[、,\s]+/)
    location_parts.map { |part| "##{part.gsub(/[^\p{L}\p{N}]/, '')}" }.reject(&:blank?)
  end

  def refresh_facebook_token!
    return false unless facebook? && access_token.present?

    begin
      # Facebook long-lived token refresh
      koala = Koala::Facebook::API.new(access_token)
      oauth = Koala::Facebook::OAuth.new(client_id, client_secret)

      new_token = oauth.exchange_access_token_info(access_token)

      update!(
        access_token: new_token["access_token"],
        expires_at: Time.current + new_token["expires"].to_i.seconds,
        status: :connected
      )

      true
    rescue => error
      update!(status: :expired, last_post_error: error.message)
      false
    end
  end

  def refresh_twitter_token!
    return false unless twitter? && refresh_token.present?

    begin
      # Twitter OAuth 2.0 token refresh
      oauth_client = OAuth2::Client.new(
        client_id,
        client_secret,
        site: "https://api.twitter.com",
        token_url: "/2/oauth2/token"
      )

      token = OAuth2::AccessToken.from_hash(
        oauth_client,
        refresh_token: refresh_token
      )

      new_token = token.refresh!

      update!(
        access_token: new_token.token,
        refresh_token: new_token.refresh_token,
        expires_at: Time.current + new_token.expires_in.seconds,
        status: :connected
      )

      true
    rescue => error
      update!(status: :expired, last_post_error: error.message)
      false
    end
  end

  def refresh_instagram_token!
    return false unless instagram? && access_token.present?

    begin
      # Instagram Basic Display API token refresh
      response = HTTParty.get(
        "https://graph.instagram.com/refresh_access_token",
        query: {
          grant_type: "ig_refresh_token",
          access_token: access_token
        }
      )

      if response.success?
        data = JSON.parse(response.body)

        update!(
          access_token: data["access_token"],
          expires_at: Time.current + data["expires_in"].seconds,
          status: :connected
        )

        true
      else
        update!(status: :expired, last_post_error: "Token refresh failed: #{response.code}")
        false
      end
    rescue => error
      update!(status: :expired, last_post_error: error.message)
      false
    end
  end
end
