class CreateFlags < ActiveRecord::Migration[7.2]
  def change
    create_table :flags do |t|
      t.bigint :episode_ref, null: false
      t.jsonb :evaluation_refs, null: false, default: []
      t.string :severity, null: false
      t.string :subtype, null: false
      t.string :state, null: false, default: "open"
      t.datetime :sla_deadline_at
      t.datetime :opened_at, null: false
      t.datetime :first_action_at
      t.datetime :resolved_at
      t.string :outcome
      t.boolean :breach, null: false, default: false

      t.timestamps
    end

    add_foreign_key :flags, :episodes, column: :episode_ref
    add_index :flags, :episode_ref
    add_index :flags, :state
    add_index :flags, :sla_deadline_at

    add_check_constraint :flags, "severity IN ('green','yellow','red')", name: "flags_severity_check"
    add_check_constraint :flags, "subtype IN ('clinical','adherence','manual')", name: "flags_subtype_check"
    add_check_constraint :flags, "state IN ('open','in_progress','resolved')", name: "flags_state_check"
  end
end
