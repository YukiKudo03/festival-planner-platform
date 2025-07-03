class CreateBooths < ActiveRecord::Migration[8.0]
  def change
    create_table :booths do |t|
      t.references :venue_area, null: false, foreign_key: true
      t.references :festival, null: false, foreign_key: true
      t.references :vendor_application, null: false, foreign_key: true
      t.string :name
      t.string :booth_number
      t.string :size
      t.decimal :width
      t.decimal :height
      t.decimal :x_position
      t.decimal :y_position
      t.decimal :rotation
      t.string :status
      t.boolean :power_required
      t.boolean :water_required
      t.text :special_requirements
      t.text :setup_instructions

      t.timestamps
    end
  end
end
