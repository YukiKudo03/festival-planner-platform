class CreateMunicipalAuthorities < ActiveRecord::Migration[8.0]
  def change
    create_table :municipal_authorities do |t|
      t.string :name, null: false
      t.string :authority_type, null: false
      t.string :contact_person
      t.string :email
      t.string :phone
      t.text :address
      t.string :code
      t.string :api_endpoint
      t.string :api_key
      t.text :description

      t.timestamps
    end
    
    add_index :municipal_authorities, :authority_type
    add_index :municipal_authorities, :code, unique: true
    add_index :municipal_authorities, :email
  end
end
