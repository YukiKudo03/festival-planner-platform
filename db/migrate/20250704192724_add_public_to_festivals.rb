class AddPublicToFestivals < ActiveRecord::Migration[8.0]
  def change
    add_column :festivals, :public, :boolean, default: false, null: false
  end
end
