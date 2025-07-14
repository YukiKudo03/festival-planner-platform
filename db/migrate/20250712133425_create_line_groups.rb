class CreateLineGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :line_groups do |t|
      t.references :line_integration, null: false, foreign_key: true
      t.string :line_group_id, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :is_active, default: true
      t.integer :member_count, default: 0
      t.datetime :last_activity_at
      t.text :group_settings

      t.timestamps
    end

    add_index :line_groups, :line_group_id, unique: true
    add_index :line_groups, [ :line_integration_id, :line_group_id ], unique: true
    add_index :line_groups, :is_active
    add_index :line_groups, :last_activity_at
  end
end
