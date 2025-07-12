class CreateIndustrySpecializations < ActiveRecord::Migration[8.0]
  def change
    create_table :industry_specializations do |t|
      t.references :festival, null: false, foreign_key: true
      t.string :industry_type, null: false
      t.string :specialization_level, null: false, default: 'basic'
      t.string :status, null: false, default: 'planning'
      t.boolean :certification_required, default: false
      t.text :description
      t.string :priority, default: 'medium'
      t.string :specialization_code
      t.datetime :activated_at
      t.datetime :completed_at
      t.text :completion_notes
      t.text :compliance_standards
      t.text :specialized_features
      t.text :industry_regulations
      t.text :certification_requirements
      t.text :performance_kpis
      t.text :vendor_criteria

      t.timestamps
    end
    
    add_index :industry_specializations, :industry_type
    add_index :industry_specializations, :status
    add_index :industry_specializations, :specialization_code, unique: true
    add_index :industry_specializations, [:festival_id, :industry_type], unique: true
  end
end
