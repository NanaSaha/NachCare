class CreateDrugs < ActiveRecord::Migration[7.2]
  def change
    create_table :drugs do |t|
      t.string :name, null: false
      t.string :category

      t.timestamps
    end

    add_index :drugs, :name, unique: true

    # Section 5's medications.drug_ref was a loose string until the local
    # drug table existed (M0 predates M1's enrollment work). Now it does.
    change_column :medications, :drug_ref, :bigint, using: "NULL"
    add_foreign_key :medications, :drugs, column: :drug_ref
    add_index :medications, :drug_ref
  end
end
