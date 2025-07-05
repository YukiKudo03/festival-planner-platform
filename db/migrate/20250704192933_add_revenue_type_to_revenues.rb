class AddRevenueTypeToRevenues < ActiveRecord::Migration[8.0]
  def change
    add_column :revenues, :revenue_type, :string, null: false, default: 'other'
  end
end
