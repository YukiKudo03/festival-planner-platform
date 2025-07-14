class CreateLineIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :line_integrations do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :line_channel_id, null: false
      t.string :line_channel_secret, null: false
      t.string :line_access_token, null: false
      t.string :webhook_url
      t.text :settings
      t.integer :status, default: 0
      t.boolean :is_active, default: false
      t.string :line_user_id
      t.string :notification_preferences
      t.datetime :last_sync_at
      t.datetime :last_webhook_received_at

      t.timestamps
    end

    add_index :line_integrations, :line_channel_id, unique: true
    add_index :line_integrations, [ :festival_id, :user_id ], unique: true
    add_index :line_integrations, :status
    add_index :line_integrations, :is_active
  end
end
