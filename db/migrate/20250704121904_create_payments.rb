class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :festival, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :payment_method, null: false
      t.string :status, null: false, default: 'pending'
      t.string :currency, default: 'JPY'
      t.text :description
      t.string :customer_email
      t.string :customer_name
      t.text :billing_address
      t.string :external_transaction_id
      t.decimal :processing_fee, precision: 8, scale: 2, default: 0
      t.json :metadata, default: {}
      t.datetime :processed_at
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.text :cancellation_reason
      t.text :error_message

      t.timestamps
    end
    
    add_index :payments, :status
    add_index :payments, :payment_method
    add_index :payments, :external_transaction_id, unique: true
    add_index :payments, [:festival_id, :status]
    add_index :payments, [:user_id, :status]
    add_index :payments, :processed_at
    add_index :payments, :confirmed_at
  end
end
