class CreateFileAccessLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :file_access_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :attachment_id, null: false
      t.string :action, null: false
      t.string :ip_address, null: false
      t.text :user_agent, null: false

      t.timestamps
    end

    add_index :file_access_logs, :attachment_id
    add_index :file_access_logs, [ :user_id, :created_at ]
    add_index :file_access_logs, [ :action, :created_at ]
    add_index :file_access_logs, :created_at
  end
end
