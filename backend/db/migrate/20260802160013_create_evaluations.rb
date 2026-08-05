class CreateEvaluations < ActiveRecord::Migration[7.2]
  def change
    create_table :evaluations do |t|
      t.bigint :check_in_ref
      t.bigint :episode_ref, null: false
      t.string :ruleset_version, null: false
      t.string :inputs_sha256, null: false
      t.string :severity, null: false
      t.jsonb :fired_rules, null: false, default: []

      t.datetime :created_at, null: false
    end

    add_foreign_key :evaluations, :check_ins, column: :check_in_ref
    add_foreign_key :evaluations, :episodes, column: :episode_ref
    add_index :evaluations, :check_in_ref
    add_index :evaluations, :episode_ref
    add_index :evaluations, :inputs_sha256

    add_check_constraint :evaluations, "severity IN ('green','yellow','red')", name: "evaluations_severity_check"
  end
end
