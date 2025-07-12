class AddLineEnabledToNotificationSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :notification_settings, :line_enabled, :boolean, default: false, null: false
    add_index :notification_settings, :line_enabled
  end
end
