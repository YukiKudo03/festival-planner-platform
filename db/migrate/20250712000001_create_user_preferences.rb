class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # Basic preferences
      t.string :language, limit: 10
      t.string :timezone, limit: 50

      # Dashboard customization
      t.text :dashboard_widgets
      t.text :dashboard_layout

      # Notification preferences
      t.text :notification_preferences

      # Theme and display preferences
      t.text :theme_settings

      # Quick access and shortcuts
      t.text :quick_actions
      t.text :favorite_features

      # Accessibility options
      t.boolean :high_contrast_mode, default: false
      t.boolean :screen_reader_optimized, default: false
      t.integer :font_scale, default: 100, limit: 1

      # Performance preferences
      t.boolean :enable_animations, default: true
      t.boolean :auto_refresh_enabled, default: true
      t.integer :auto_refresh_interval, default: 30

      t.timestamps
    end

    add_index :user_preferences, :language
    add_index :user_preferences, :timezone
    add_index :user_preferences, :high_contrast_mode
    add_index :user_preferences, :screen_reader_optimized
  end
end
