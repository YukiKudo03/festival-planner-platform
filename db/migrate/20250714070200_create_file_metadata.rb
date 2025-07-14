class CreateFileMetadata < ActiveRecord::Migration[8.0]
  def change
    create_table :file_metadata do |t|
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.integer :attachment_id, null: false
      t.string :original_filename, null: false
      t.bigint :file_size, null: false
      t.string :content_type, null: false
      t.string :upload_ip, null: false
      t.text :upload_user_agent, null: false
      t.json :image_metadata
      t.json :processing_metadata

      t.timestamps
    end

    add_index :file_metadata, :attachment_id, unique: true
    add_index :file_metadata, :uploaded_by_id unless index_exists?(:file_metadata, :uploaded_by_id)
    add_index :file_metadata, :content_type
    add_index :file_metadata, :file_size
    add_index :file_metadata, :created_at
  end
end
