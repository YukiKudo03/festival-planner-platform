class CreateReactions < ActiveRecord::Migration[8.0]
  def change
    create_table :reactions do |t|
      t.references :reactable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.string :reaction_type

      t.timestamps
    end
  end
end
