class CreateFestivals < ActiveRecord::Migration[8.0]
  def change
    create_table :festivals do |t|
      t.string :name
      t.text :description
      t.datetime :start_date
      t.datetime :end_date
      t.string :location
      t.decimal :budget
      t.integer :status
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
