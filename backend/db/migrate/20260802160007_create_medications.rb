class CreateMedications < ActiveRecord::Migration[7.2]
  def change
    create_table :medications do |t|
      t.bigint :care_plan_ref, null: false
      t.string :name, null: false
      t.string :drug_ref
      t.boolean :critical, null: false, default: false
      t.jsonb :schedule, null: false, default: {}

      t.timestamps
    end

    add_foreign_key :medications, :care_plans, column: :care_plan_ref
    add_index :medications, :care_plan_ref
  end
end
