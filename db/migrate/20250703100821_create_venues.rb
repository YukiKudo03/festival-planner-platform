class CreateVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :venues do |t|
      t.references :festival, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :capacity, null: false
      t.text :address
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :facility_type, null: false
      t.text :contact_info

      t.timestamps
    end
    
    add_index :venues, :festival_id
    add_index :venues, :facility_type
    add_index :venues, [:latitude, :longitude]
  end
end
