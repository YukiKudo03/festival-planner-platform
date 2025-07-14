class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :api_key, null: false
      t.string :key_type, null: false, default: 'personal'
      t.text :scopes
      t.text :ip_whitelist
      t.text :rate_limits
      t.datetime :expires_at
      t.boolean :active, default: true
      t.integer :request_count, default: 0
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.text :usage_stats

      t.timestamps
    end

    add_index :api_keys, :api_key, unique: true
    add_index :api_keys, :key_type
    add_index :api_keys, [ :active, :expires_at ]
    add_index :api_keys, :last_used_at
  end
end
