class AddApiFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :api_token, :string
    add_column :users, :api_token_expires_at, :datetime
    add_column :users, :last_api_access_at, :datetime
    add_column :users, :api_request_count, :integer, default: 0
    add_column :users, :api_permissions, :json, default: {}
    
    add_index :users, :api_token, unique: true
    add_index :users, :api_token_expires_at
    add_index :users, :last_api_access_at
  end
end
