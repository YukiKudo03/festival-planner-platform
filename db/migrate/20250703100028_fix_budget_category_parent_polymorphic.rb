class FixBudgetCategoryParentPolymorphic < ActiveRecord::Migration[8.0]
  def change
    change_column_null :budget_categories, :parent_type, true
    change_column_null :budget_categories, :parent_id, true
  end
end
