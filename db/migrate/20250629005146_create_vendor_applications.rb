class CreateVendorApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :vendor_applications do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :business_name
      t.string :business_type
      t.text :description
      t.text :requirements
      t.integer :status

      t.timestamps
    end
  end
end
