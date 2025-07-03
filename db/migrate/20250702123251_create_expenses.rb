class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :budget_category, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount
      t.text :description
      t.date :expense_date
      t.string :payment_method
      t.string :vendor_name
      t.string :receipt_number
      t.string :status

      t.timestamps
    end
  end
end
