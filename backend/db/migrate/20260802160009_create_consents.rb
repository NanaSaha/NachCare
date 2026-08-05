class CreateConsents < ActiveRecord::Migration[7.2]
  def change
    create_table :consents do |t|
      t.uuid :caregiver_ref, null: false
      t.string :kind, null: false
      t.integer :version, null: false
      t.boolean :granted, null: false
      t.datetime :timestamp, null: false

      t.timestamps
    end

    add_foreign_key :consents, :caregivers, column: :caregiver_ref
    add_index :consents, :caregiver_ref
    add_index :consents, [ :caregiver_ref, :kind, :version ], unique: true, name: "index_consents_on_caregiver_kind_version"

    add_check_constraint :consents, "kind IN ('a','b','c','d')", name: "consents_kind_check"
  end
end
