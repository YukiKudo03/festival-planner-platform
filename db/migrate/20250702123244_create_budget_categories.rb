class CreateBudgetCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_categories do |t|
      t.references :festival, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.references :parent, polymorphic: true, null: false
      t.decimal :budget_limit

      t.timestamps
    end
  end
end
