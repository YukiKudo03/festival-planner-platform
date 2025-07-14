class CreateApplicationComments < ActiveRecord::Migration[8.0]
  def change
    create_table :application_comments do |t|
      t.references :vendor_application, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :internal, default: false, null: false

      t.timestamps
    end

    add_index :application_comments, [ :vendor_application_id, :created_at ]
    add_index :application_comments, [ :user_id, :created_at ]
    add_index :application_comments, :internal
  end
end
