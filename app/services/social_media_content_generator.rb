class SocialMediaContentGenerator
  include Rails.application.routes.url_helpers

  def initialize(festival, integration = nil)
    @festival = festival
    @integration = integration
  end

  def generate_announcement_series
    [
      generate_save_the_date,
      generate_lineup_announcement,
      generate_ticket_announcement,
      generate_countdown_series,
      generate_day_of_event,
      generate_thank_you_post
    ].flatten.compact
  end

  def generate_save_the_date
    return nil unless @festival.start_date

    {
      type: "save_the_date",
      content: build_save_the_date_content,
      hashtags: base_hashtags + [ "#SaveTheDate", "#予告" ],
      scheduled_time: optimal_post_time(30.days.ago),
      image_suggestion: "festival_logo_or_venue",
      platforms: [ "facebook", "twitter", "instagram" ]
    }
  end

  def generate_lineup_announcement
    return nil unless @festival.description.present?

    {
      type: "lineup_announcement",
      content: build_lineup_content,
      hashtags: base_hashtags + [ "#lineup", "#ラインナップ", "#出演者" ],
      scheduled_time: optimal_post_time(14.days.ago),
      image_suggestion: "lineup_poster",
      platforms: [ "facebook", "twitter", "instagram" ]
    }
  end

  def generate_ticket_announcement
    {
      type: "ticket_announcement",
      content: build_ticket_content,
      hashtags: base_hashtags + [ "#チケット", "#申込", "#参加者募集" ],
      scheduled_time: optimal_post_time(21.days.ago),
      image_suggestion: "ticket_info_graphic",
      platforms: [ "facebook", "twitter", "instagram" ]
    }
  end

  def generate_countdown_series
    return [] unless @festival.start_date

    countdown_days = [ 30, 14, 7, 3, 1 ]

    countdown_days.map do |days|
      scheduled_date = @festival.start_date - days.days
      next if scheduled_date < Date.current

      {
        type: "countdown",
        content: build_countdown_content(days),
        hashtags: base_hashtags + [ "#あと#{days}日", "#カウントダウン" ],
        scheduled_time: optimal_post_time(scheduled_date),
        image_suggestion: "countdown_#{days}_days",
        platforms: [ "facebook", "twitter", "instagram" ]
      }
    end.compact
  end

  def generate_day_of_event
    return nil unless @festival.start_date

    [
      {
        type: "morning_greeting",
        content: build_morning_greeting,
        hashtags: base_hashtags + [ "#当日", "#開催中" ],
        scheduled_time: @festival.start_date.beginning_of_day + 8.hours,
        image_suggestion: "morning_setup_or_venue",
        platforms: [ "facebook", "twitter", "instagram" ]
      },
      {
        type: "live_updates",
        content: build_live_update_template,
        hashtags: base_hashtags + [ "#ライブ配信", "#リアルタイム" ],
        scheduled_time: @festival.start_date.beginning_of_day + 12.hours,
        image_suggestion: "live_event_photos",
        platforms: [ "facebook", "twitter", "instagram" ]
      }
    ]
  end

  def generate_thank_you_post
    return nil unless @festival.end_date

    {
      type: "thank_you",
      content: build_thank_you_content,
      hashtags: base_hashtags + [ "#ありがとうございました", "#感謝", "#終了" ],
      scheduled_time: (@festival.end_date || @festival.start_date).end_of_day + 2.hours,
      image_suggestion: "event_highlights_collage",
      platforms: [ "facebook", "twitter", "instagram" ]
    }
  end

  def generate_behind_scenes_content
    behind_scenes_posts = []

    # Preparation phase
    if @festival.start_date > 7.days.from_now
      behind_scenes_posts << {
        type: "preparation",
        content: build_preparation_content,
        hashtags: base_hashtags + [ "#準備中", "#舞台裏", "#BehindTheScenes" ],
        image_suggestion: "preparation_photos",
        platforms: [ "facebook", "instagram" ]
      }
    end

    # Setup phase
    if @festival.start_date > 1.day.from_now
      behind_scenes_posts << {
        type: "setup",
        content: build_setup_content,
        hashtags: base_hashtags + [ "#設営", "#準備完了", "#もうすぐ" ],
        image_suggestion: "setup_photos",
        platforms: [ "facebook", "twitter", "instagram" ]
      }
    end

    behind_scenes_posts
  end

  def generate_engagement_content
    [
      generate_quiz_content,
      generate_poll_content,
      generate_user_generated_content_prompt,
      generate_memory_sharing_prompt
    ].compact
  end

  def generate_quiz_content
    return nil unless @festival.location.present?

    {
      type: "quiz",
      content: build_quiz_content,
      hashtags: base_hashtags + [ "#クイズ", "#参加型", "#楽しもう" ],
      image_suggestion: "quiz_graphic",
      platforms: [ "facebook", "twitter" ]
    }
  end

  def generate_poll_content
    {
      type: "poll",
      content: build_poll_content,
      hashtags: base_hashtags + [ "#アンケート", "#投票", "#意見募集" ],
      poll_options: [ "期待している出し物", "好きな時間帯", "参加予定の友達数" ],
      platforms: [ "facebook", "twitter", "instagram" ]
    }
  end

  def generate_user_generated_content_prompt
    {
      type: "ugc_prompt",
      content: build_ugc_prompt,
      hashtags: base_hashtags + [ "#投稿募集", "#みんなの写真", "#シェア" ],
      platforms: [ "facebook", "twitter", "instagram" ]
    }
  end

  def generate_memory_sharing_prompt
    {
      type: "memory_sharing",
      content: build_memory_sharing_content,
      hashtags: base_hashtags + [ "#思い出", "#昨年の様子", "#継続" ],
      platforms: [ "facebook", "instagram" ]
    }
  end

  def generate_platform_specific_content(platform)
    case platform
    when "facebook"
      generate_facebook_specific_content
    when "twitter"
      generate_twitter_specific_content
    when "instagram"
      generate_instagram_specific_content
    else
      []
    end
  end

  def generate_hashtag_strategy
    {
      primary_hashtags: base_hashtags.take(5),
      secondary_hashtags: secondary_hashtags,
      trending_hashtags: find_trending_hashtags,
      location_hashtags: location_hashtags,
      time_based_hashtags: time_based_hashtags,
      platform_specific: {
        facebook: facebook_hashtags,
        twitter: twitter_hashtags,
        instagram: instagram_hashtags
      }
    }
  end

  private

  def build_save_the_date_content
    "📅 Save the Date!\n\n" +
    "#{@festival.name}\n" +
    "📍 #{@festival.location}\n" +
    "📆 #{@festival.start_date&.strftime('%Y年%m月%d日')}#{@festival.end_date ? " - #{@festival.end_date.strftime('%m月%d日')}" : ""}\n\n" +
    "詳細は近日発表予定！お楽しみに✨\n\n" +
    "#SaveTheDate #予告 #お楽しみに"
  end

  def build_lineup_content
    content = "🎪 #{@festival.name} 開催内容発表！\n\n"

    if @festival.description.present?
      content += "#{@festival.description}\n\n"
    end

    # Add task-based content highlights
    if @festival.tasks.any?
      highlighted_tasks = @festival.tasks.limit(3)
      content += "今回の見どころ：\n"
      highlighted_tasks.each do |task|
        content += "• #{task.title}\n"
      end
      content += "\n"
    end

    content += "皆さまのお越しをお待ちしております！\n\n"
    content += "#ラインナップ #見どころ #期待"
  end

  def build_ticket_content
    content = "🎫 #{@festival.name} 参加者募集開始！\n\n"
    content += "📅 開催日：#{@festival.start_date&.strftime('%Y年%m月%d日')}\n"
    content += "📍 会場：#{@festival.location}\n\n"

    if @festival.budget.present?
      content += "💰 参加費：詳細はお問い合わせください\n"
    end

    content += "\n申込方法や詳細情報は公式サイトをチェック！\n"
    content += "🔗 #{festival_url(@festival)}\n\n" if defined?(festival_url)
    content += "#参加者募集 #申込開始 #お申し込み"
  end

  def build_countdown_content(days)
    case days
    when 30
      "🗓️ #{@festival.name}まで残り1ヶ月！\n\n準備も本格化してきました。皆さんにお会いできるのを楽しみにしています✨"
    when 14
      "📆 #{@festival.name}まであと2週間！\n\n最終準備に入りました。当日の天気も良さそうです☀️"
    when 7
      "⏰ #{@festival.name}まで1週間を切りました！\n\nスタッフ一同、心を込めて準備しています。もうすぐお会いできますね🎉"
    when 3
      "🚀 #{@festival.name}まであと3日！\n\n設営も順調に進んでいます。皆さんの笑顔を見るのが待ち遠しいです😊"
    when 1
      "🌟 いよいよ明日#{@festival.name}開催！\n\n最後の確認をして、明日に備えます。皆さんにお会いできるのを心待ちにしています💫"
    else
      "🎪 #{@festival.name}まであと#{days}日！\n\n準備着々と進んでいます。お楽しみに！"
    end
  end

  def build_morning_greeting
    "🌅 おはようございます！\n\n" +
    "本日#{@festival.name}開催日です！\n" +
    "スタッフ一同、早朝から最終準備を行っています。\n\n" +
    "皆さまのお越しを心よりお待ちしております🎪\n\n" +
    "📍 #{@festival.location}\n" +
    "⏰ 開始時刻などの詳細は公式情報をご確認ください"
  end

  def build_live_update_template
    "📸 #{@festival.name} 開催中！\n\n" +
    "会場の様子をお届けします✨\n" +
    "[ここに当日の写真や動画を追加]\n\n" +
    "まだ間に合います！ぜひお越しください🎉"
  end

  def build_thank_you_content
    "🙏 #{@festival.name}、無事終了いたしました！\n\n" +
    "ご来場いただいた皆さま、ご協力いただいた関係者の皆さま、" +
    "本当にありがとうございました。\n\n" +
    "皆さまの笑顔が見られて、スタッフ一同大変嬉しく思います。\n" +
    "また来年もお会いできることを楽しみにしています✨\n\n" +
    "#ありがとうございました #感謝 #また来年"
  end

  def build_preparation_content
    "🔧 #{@festival.name}の準備風景をちょっとだけお見せします！\n\n" +
    "実行委員会のメンバーが集まって、細かい打ち合わせ中📝\n" +
    "皆さんに喜んでもらえるよう、一生懸命準備しています💪\n\n" +
    "当日をお楽しみに！"
  end

  def build_setup_content
    "🏗️ #{@festival.name}の設営が始まりました！\n\n" +
    "会場が少しずつ祭りの雰囲気になってきています🎪\n" +
    "明日（または当日）の本番に向けて、最後の仕上げです✨\n\n" +
    "準備万端でお待ちしています！"
  end

  def build_quiz_content
    "🤔 #{@festival.name}クイズ！\n\n" +
    "Q: #{@festival.location}で開催される#{@festival.name}。" +
    "このイベントの特徴は何でしょう？\n\n" +
    "ヒント：#{@festival.description&.slice(0, 30)}...\n\n" +
    "コメントで答えを教えてください！"
  end

  def build_poll_content
    "📊 #{@festival.name}に関するアンケート！\n\n" +
    "皆さんが一番楽しみにしていることは何ですか？\n" +
    "コメントで教えてください😊\n\n" +
    "皆さんの声を参考に、より良いイベントにしていきます！"
  end

  def build_ugc_prompt
    "📷 #{@festival.name}の思い出を共有しませんか？\n\n" +
    "当日撮影した写真や動画に #{base_hashtags.first} をつけて投稿してください！\n" +
    "素敵な投稿は公式アカウントでシェアさせていただきます✨\n\n" +
    "皆さんの視点から見た祭りの様子、とても楽しみです📸"
  end

  def build_memory_sharing_content
    "💭 思い出のシェア\n\n" +
    "#{@festival.name}の準備や開催を通じて、" +
    "たくさんの素敵な思い出ができました。\n\n" +
    "地域の皆さんと一緒に作り上げる祭りの魅力を、" +
    "改めて感じています🌟\n\n" +
    "来年も皆さんと一緒に素晴らしいイベントを作りましょう！"
  end

  def base_hashtags
    return @base_hashtags if @base_hashtags

    @base_hashtags = [ "##{@festival.name.gsub(/\s+/, '')}" ]
    @base_hashtags << "##{@festival.location.gsub(/[^\p{L}\p{N}]/, '')}" if @festival.location
    @base_hashtags += [ "#祭り", "#フェスティバル", "#地域イベント" ]
    @base_hashtags
  end

  def secondary_hashtags
    tags = [ "#地域活性化", "#コミュニティ", "#楽しい時間" ]

    if @festival.start_date
      tags << "##{@festival.start_date.strftime('%Y年%m月')}"
    end

    tags
  end

  def location_hashtags
    return [] unless @festival.location

    location_parts = @festival.location.split(/[、,\s]+/)
    location_parts.map { |part| "##{part.gsub(/[^\p{L}\p{N}]/, '')}" }.reject(&:blank?)
  end

  def time_based_hashtags
    return [] unless @festival.start_date

    date = @festival.start_date
    [
      "##{date.year}年",
      "##{date.strftime('%m月')}",
      "##{date.strftime('%B').downcase}" # English month for international reach
    ]
  end

  def facebook_hashtags
    [ "#FacebookEvent", "#コミュニティイベント" ]
  end

  def twitter_hashtags
    [ "#ツイッター投稿", "#リアルタイム" ]
  end

  def instagram_hashtags
    [ "#インスタ映え", "#写真", "#思い出" ]
  end

  def find_trending_hashtags
    # This would integrate with social media APIs to find trending hashtags
    # For now, return some generic trending festival hashtags
    [ "#週末イベント", "#家族連れ歓迎", "#地元愛" ]
  end

  def optimal_post_time(date = Date.current)
    # Optimal posting times based on social media best practices
    # Facebook: 1-3 PM on weekdays
    # Twitter: 8-10 AM and 7-9 PM
    # Instagram: 11 AM - 1 PM and 7-9 PM

    if date.on_weekday?
      date.beginning_of_day + 14.hours # 2 PM
    else
      date.beginning_of_day + 12.hours # 12 PM on weekends
    end
  end

  def generate_facebook_specific_content
    # Facebook allows longer content and better engagement features
    [
      {
        type: "facebook_event",
        content: build_facebook_event_content,
        hashtags: base_hashtags + facebook_hashtags,
        platforms: [ "facebook" ]
      }
    ]
  end

  def generate_twitter_specific_content
    # Twitter requires shorter, more frequent content
    [
      {
        type: "twitter_thread",
        content: build_twitter_thread_content,
        hashtags: base_hashtags + twitter_hashtags,
        platforms: [ "twitter" ]
      }
    ]
  end

  def generate_instagram_specific_content
    # Instagram is visual-first
    [
      {
        type: "instagram_story",
        content: build_instagram_story_content,
        hashtags: base_hashtags + instagram_hashtags,
        platforms: [ "instagram" ]
      }
    ]
  end

  def build_facebook_event_content
    "🎉 #{@festival.name} 開催決定！\n\n" +
    "地域の皆さんと一緒に作り上げる特別なイベントです。\n" +
    "家族連れでも楽しめる内容盛りだくさん！\n\n" +
    "📅 #{@festival.start_date&.strftime('%Y年%m月%d日')}\n" +
    "📍 #{@festival.location}\n\n" +
    "詳細はコメント欄やメッセージでお気軽にお尋ねください！"
  end

  def build_twitter_thread_content
    "🧵 #{@festival.name}について、スレッドで詳しくご紹介します！\n\n1/5"
  end

  def build_instagram_story_content
    "📸 #{@festival.name}の準備の様子をストーリーでお届け！\n\n" +
    "スワイプして舞台裏をチェック👉"
  end
end
