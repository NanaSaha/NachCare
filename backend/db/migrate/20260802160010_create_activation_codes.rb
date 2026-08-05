class CreateActivationCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :activation_codes do |t|
      t.bigint :episode_ref, null: false
      t.string :code_digest, null: false
      t.string :role, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_foreign_key :activation_codes, :episodes, column: :episode_ref
    add_index :activation_codes, :episode_ref
    add_index :activation_codes, :code_digest, unique: true

    add_check_constraint :activation_codes, "role IN ('primary','secondary')", name: "activation_codes_role_check"
  end
end
