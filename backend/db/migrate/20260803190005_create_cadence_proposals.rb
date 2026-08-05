# UC-24: post-promotion cadence-adaptation proposals ([RISK] proposes
# taper/densify -> nurse one-click approves -> versioned into the care
# plan via `care_plans.cadence`, the existing unused jsonb column). Kept
# as its own small table rather than writing directly into `care_plans`
# so a *proposed* cadence never lands on the live care plan until a nurse
# actually approves it — nurse-approved is the only path that creates a
# new CarePlan version (design decision #3 in UC-24's spec text: "the
# model never silently changes what a family is asked to do").
class CreateCadenceProposals < ActiveRecord::Migration[7.2]
  def change
    create_table :cadence_proposals do |t|
      t.bigint :episode_ref, null: false
      t.string :direction, null: false
      t.jsonb :proposed_cadence, null: false, default: {}
      t.text :rationale
      t.string :status, null: false, default: "pending"
      t.bigint :decided_by
      t.datetime :decided_at

      t.timestamps
    end

    add_foreign_key :cadence_proposals, :episodes, column: :episode_ref
    add_foreign_key :cadence_proposals, :users, column: :decided_by
    add_index :cadence_proposals, :episode_ref
    add_index :cadence_proposals, :status

    add_check_constraint :cadence_proposals, "direction IN ('taper','densify')", name: "cadence_proposals_direction_check"
    add_check_constraint :cadence_proposals, "status IN ('pending','approved','dismissed')", name: "cadence_proposals_status_check"
  end
end
