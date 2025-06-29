class CreateNotificationSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notification_type, null: false
      t.boolean :email_enabled, default: true
      t.boolean :web_enabled, default: true
      t.string :frequency, default: 'immediate'

      t.timestamps
    end

    add_index :notification_settings, [:user_id, :notification_type], unique: true
    add_index :notification_settings, :notification_type
  end
end
