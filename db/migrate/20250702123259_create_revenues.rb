class CreateRevenues < ActiveRecord::Migration[8.0]
  def change
    create_table :revenues do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :budget_category, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.text :description, null: false
      t.date :revenue_date, null: false
      t.string :revenue_type, null: false
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end
    
    add_index :revenues, :revenue_date
    add_index :revenues, :revenue_type
    add_index :revenues, :status
    add_index :revenues, [:festival_id, :revenue_date]
    add_index :revenues, [:budget_category_id, :status]
  end
end
