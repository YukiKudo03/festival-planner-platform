class CreateForums < ActiveRecord::Migration[8.0]
  def change
    create_table :forums do |t|
      t.references :festival, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :category
      t.boolean :private

      t.timestamps
    end
  end
end
