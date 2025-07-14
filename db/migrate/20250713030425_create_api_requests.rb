class CreateApiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :api_requests do |t|
      t.references :api_key, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :endpoint, null: false
      t.string :method, null: false
      t.string :ip_address, null: false
      t.text :user_agent
      t.integer :response_status, null: false
      t.float :response_time_ms

      t.timestamps
    end

    add_index :api_requests, :endpoint
    add_index :api_requests, :method
    add_index :api_requests, :ip_address
    add_index :api_requests, :response_status
    add_index :api_requests, :created_at
    add_index :api_requests, [ :api_key_id, :created_at ]
    add_index :api_requests, [ :response_status, :created_at ]
  end
end
