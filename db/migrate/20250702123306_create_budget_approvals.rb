class CreateBudgetApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_approvals do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :budget_category, null: false, foreign_key: true
      t.references :approver, polymorphic: true, null: false
      t.decimal :requested_amount, precision: 10, scale: 2, null: false
      t.decimal :approved_amount, precision: 10, scale: 2, null: false, default: 0
      t.string :status, null: false, default: 'pending'
      t.text :notes

      t.timestamps
    end
    
    add_index :budget_approvals, :status
    add_index :budget_approvals, [:festival_id, :status]
    add_index :budget_approvals, [:budget_category_id, :status]
  end
end
