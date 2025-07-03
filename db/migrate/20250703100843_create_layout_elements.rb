class CreateLayoutElements < ActiveRecord::Migration[8.0]
  def change
    create_table :layout_elements do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :element_type
      t.string :name
      t.text :description
      t.decimal :x_position
      t.decimal :y_position
      t.decimal :width
      t.decimal :height
      t.decimal :rotation
      t.string :color
      t.text :properties
      t.integer :layer
      t.boolean :locked
      t.boolean :visible

      t.timestamps
    end
  end
end
