class CreateCheckIns < ActiveRecord::Migration[7.2]
  def change
    create_table :check_ins do |t|
      t.uuid :client_uuid, null: false
      t.bigint :episode_ref, null: false
      t.uuid :caregiver_ref, null: false
      t.datetime :submitted_at, null: false
      t.date :effective_date, null: false
      t.decimal :weight_kg, precision: 5, scale: 2
      t.string :weight_source, null: false, default: "manual"
      t.jsonb :med_status, null: false, default: {}
      t.jsonb :symptoms, null: false, default: {}
      t.text :note # encrypted (Active Record encryption)
      t.string :sync_state, null: false, default: "synced"
      t.bigint :superseded_by

      t.timestamps
    end

    add_foreign_key :check_ins, :episodes, column: :episode_ref
    add_foreign_key :check_ins, :caregivers, column: :caregiver_ref
    add_foreign_key :check_ins, :check_ins, column: :superseded_by
    add_index :check_ins, :episode_ref
    add_index :check_ins, :caregiver_ref
    add_index :check_ins, :client_uuid, unique: true
    add_index :check_ins, :effective_date

    add_check_constraint :check_ins, "weight_source IN ('manual')", name: "check_ins_weight_source_check"
    add_check_constraint :check_ins, "sync_state IN ('synced','pending','conflict')", name: "check_ins_sync_state_check"
  end
end
