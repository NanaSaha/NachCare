# UC-05 (shadow trajectory tracking): a real, deterministic, fully
# explainable heuristic score computed for every check-in, paired at
# write-time with the rules-engine verdict for the same check-in
# (`rules_severity`) so the two can be compared later — this is the
# training-data value UC-05 describes, not a live-acting signal. `outcome`
# starts nil and is backfilled by Domain::Risk::OutcomeLinker once the
# episode's trajectory resolves (a flag opens/resolves within the
# follow-up window) — see ADR-0012. `alert_eligible` records whether this
# score would have crossed the (site-configurable) promoted alert gate,
# independent of whether the site is actually promoted yet — this is what
# lets Domain::Risk::PromotionGate compute alert-rate/lead-time retro-
# spectively once promotion is being considered.
class CreateRiskScores < ActiveRecord::Migration[7.2]
  def change
    create_table :risk_scores do |t|
      t.bigint :episode_ref, null: false
      t.bigint :check_in_ref, null: false
      t.decimal :score, precision: 5, scale: 4, null: false
      t.jsonb :components, null: false, default: {}
      t.string :rules_severity, null: false
      t.boolean :alert_eligible, null: false, default: false
      t.string :outcome
      t.datetime :outcome_evaluated_at

      t.timestamps
    end

    add_foreign_key :risk_scores, :episodes, column: :episode_ref
    add_foreign_key :risk_scores, :check_ins, column: :check_in_ref
    add_index :risk_scores, :episode_ref
    add_index :risk_scores, :check_in_ref, unique: true
    add_index :risk_scores, :outcome_evaluated_at

    add_check_constraint :risk_scores, "rules_severity IN ('green','yellow','red')", name: "risk_scores_rules_severity_check"
  end
end
