class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :sender, null: true, foreign_key: { to_table: :users }
      t.references :notifiable, polymorphic: true, null: false
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :message
      t.datetime :read_at
      t.datetime :sent_at

      t.timestamps
    end

    add_index :notifications, [:recipient_id, :read_at]
    add_index :notifications, [:recipient_id, :created_at]
    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, :notification_type
  end
end
