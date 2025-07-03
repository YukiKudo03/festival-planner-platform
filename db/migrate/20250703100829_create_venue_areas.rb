class CreateVenueAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :venue_areas do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :area_type, null: false
      t.decimal :width, precision: 8, scale: 2, null: false
      t.decimal :height, precision: 8, scale: 2, null: false
      t.decimal :x_position, precision: 8, scale: 2, null: false
      t.decimal :y_position, precision: 8, scale: 2, null: false
      t.decimal :rotation, precision: 5, scale: 2, default: 0
      t.string :color
      t.integer :capacity

      t.timestamps
    end
    
    add_index :venue_areas, :venue_id
    add_index :venue_areas, :area_type
    add_index :venue_areas, [:x_position, :y_position]
  end
end
