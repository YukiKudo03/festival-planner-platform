class AddWorkflowFieldsToVendorApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :vendor_applications, :submission_deadline, :datetime
    add_column :vendor_applications, :review_deadline, :datetime
    add_column :vendor_applications, :priority, :integer, default: 1
    add_column :vendor_applications, :notes, :text
    add_column :vendor_applications, :submitted_at, :datetime
    add_column :vendor_applications, :reviewed_at, :datetime
    
    add_index :vendor_applications, :submission_deadline
    add_index :vendor_applications, :review_deadline
    add_index :vendor_applications, :priority
    add_index :vendor_applications, :submitted_at
  end
end
