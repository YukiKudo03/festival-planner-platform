class CreateLineMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :line_messages do |t|
      t.references :line_group, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :line_message_id, null: false
      t.text :message_text, null: false
      t.string :message_type, default: 'text'
      t.text :parsed_content
      t.references :task, null: true, foreign_key: true
      t.boolean :is_processed, default: false
      t.string :sender_line_user_id
      t.string :sender_display_name
      t.datetime :line_timestamp
      t.text :processing_errors
      t.string :intent_type
      t.decimal :confidence_score, precision: 5, scale: 3

      t.timestamps
    end
    
    add_index :line_messages, :line_message_id, unique: true
    add_index :line_messages, [:line_group_id, :line_timestamp]
    add_index :line_messages, :is_processed
    add_index :line_messages, :intent_type
    add_index :line_messages, :sender_line_user_id
  end
end
