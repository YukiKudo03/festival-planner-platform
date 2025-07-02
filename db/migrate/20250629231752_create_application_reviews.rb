class CreateApplicationReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :application_reviews do |t|
      t.references :vendor_application, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.integer :action, null: false
      t.text :comment
      t.text :conditions
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :application_reviews, [:vendor_application_id, :created_at]
    add_index :application_reviews, [:reviewer_id, :reviewed_at]
    add_index :application_reviews, :action
  end
end
