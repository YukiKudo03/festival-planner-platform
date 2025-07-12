class UserPreference < ApplicationRecord
  belongs_to :user

  # Dashboard customization
  serialize :dashboard_widgets, Array
  serialize :dashboard_layout, Hash

  # Notification preferences
  serialize :notification_preferences, Hash

  # Theme and display preferences
  serialize :theme_settings, Hash

  # Quick access and shortcuts
  serialize :quick_actions, Array
  serialize :favorite_features, Array

  validates :user_id, presence: true, uniqueness: true
  validates :language, inclusion: { in: %w[en ja], allow_blank: true }
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name), allow_blank: true }

  # Default preferences
  after_initialize :set_defaults, if: :new_record?

  # Scopes
  scope :with_theme, ->(theme) { where("theme_settings ->> 'theme' = ?", theme) }
  scope :with_language, ->(lang) { where(language: lang) }

  def dashboard_widgets
    super.presence || default_dashboard_widgets
  end

  def notification_preferences
    super.presence || default_notification_preferences
  end

  def theme_settings
    super.presence || default_theme_settings
  end

  def quick_actions
    super.presence || default_quick_actions
  end

  def favorite_features
    super.presence || default_favorite_features
  end

  def preferred_theme
    theme_settings['theme'] || 'light'
  end

  def preferred_language
    language.presence || 'en'
  end

  def preferred_timezone
    timezone.presence || 'UTC'
  end

  def enable_feature_shortcut(feature_name)
    update(quick_actions: (quick_actions + [feature_name]).uniq)
  end

  def disable_feature_shortcut(feature_name)
    update(quick_actions: quick_actions - [feature_name])
  end

  def add_favorite_feature(feature_name)
    update(favorite_features: (favorite_features + [feature_name]).uniq)
  end

  def remove_favorite_feature(feature_name)
    update(favorite_features: favorite_features - [feature_name])
  end

  def update_notification_preference(category, enabled)
    prefs = notification_preferences.dup
    prefs[category] = enabled
    update(notification_preferences: prefs)
  end

  private

  def set_defaults
    self.language ||= 'en'
    self.timezone ||= 'UTC'
    self.dashboard_widgets ||= default_dashboard_widgets
    self.dashboard_layout ||= default_dashboard_layout
    self.notification_preferences ||= default_notification_preferences
    self.theme_settings ||= default_theme_settings
    self.quick_actions ||= default_quick_actions
    self.favorite_features ||= default_favorite_features
  end

  def default_dashboard_widgets
    %w[
      recent_festivals
      budget_overview
      pending_tasks
      vendor_applications
      upcoming_deadlines
      analytics_summary
    ]
  end

  def default_dashboard_layout
    {
      'columns' => 2,
      'widget_positions' => {
        'recent_festivals' => { 'row' => 0, 'col' => 0 },
        'budget_overview' => { 'row' => 0, 'col' => 1 },
        'pending_tasks' => { 'row' => 1, 'col' => 0 },
        'vendor_applications' => { 'row' => 1, 'col' => 1 },
        'upcoming_deadlines' => { 'row' => 2, 'col' => 0 },
        'analytics_summary' => { 'row' => 2, 'col' => 1 }
      }
    }
  end

  def default_notification_preferences
    {
      'email_notifications' => true,
      'browser_notifications' => true,
      'mobile_notifications' => true,
      'festival_updates' => true,
      'budget_alerts' => true,
      'task_reminders' => true,
      'vendor_notifications' => true,
      'chat_messages' => true,
      'forum_replies' => true,
      'system_announcements' => true
    }
  end

  def default_theme_settings
    {
      'theme' => 'light',
      'primary_color' => '#007bff',
      'secondary_color' => '#6c757d',
      'font_size' => 'medium',
      'compact_mode' => false,
      'animation_enabled' => true,
      'sidebar_collapsed' => false
    }
  end

  def default_quick_actions
    %w[
      create_festival
      create_task
      view_budget
      vendor_applications
      analytics_dashboard
    ]
  end

  def default_favorite_features
    %w[
      festivals
      budget_management
      task_management
      vendor_management
      analytics
    ]
  end
end