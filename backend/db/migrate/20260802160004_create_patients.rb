class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients, id: :uuid do |t|
      t.string :pseudonym_code, null: false
      t.string :initials, null: false
      t.integer :birth_year, null: false
      t.string :nyha_class, null: false
      t.bigint :site_ref, null: false

      t.timestamps
    end

    add_foreign_key :patients, :sites, column: :site_ref
    add_index :patients, :site_ref
    add_index :patients, :pseudonym_code, unique: true

    add_check_constraint :patients, "nyha_class IN ('I','II','III','IV')", name: "patients_nyha_class_check"
  end
end
