class CreateTourismCollaborations < ActiveRecord::Migration[8.0]
  def change
    create_table :tourism_collaborations do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :tourism_board, null: false, foreign_key: { to_table: :municipal_authorities }
      t.references :coordinator, null: false, foreign_key: { to_table: :users }
      t.string :collaboration_type, null: false
      t.string :status, null: false, default: 'proposed'
      t.string :priority, default: 'medium'
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.decimal :budget_allocation, precision: 12, scale: 2, null: false
      t.integer :expected_visitors, null: false
      t.string :collaboration_number
      t.datetime :activated_at
      t.datetime :completed_at
      t.datetime :approved_at
      t.integer :approved_by
      t.datetime :cancelled_at
      t.integer :cancelled_by
      t.text :cancellation_reason
      t.text :completion_notes
      t.text :approval_notes
      t.text :description
      t.text :marketing_objectives
      t.text :target_demographics
      t.text :promotional_channels
      t.text :collaboration_benefits
      t.text :performance_metrics
      t.text :visitor_data

      t.timestamps
    end

    add_index :tourism_collaborations, :collaboration_type
    add_index :tourism_collaborations, :status
    add_index :tourism_collaborations, :collaboration_number, unique: true
    add_index :tourism_collaborations, [ :start_date, :end_date ]
  end
end
