# UC-21: MD/ADM-gated shadow-model promotion, per site. Every gate
# evaluation (whether or not it results in promotion) gets a row here —
# "versioned and audited" per the task brief, mirroring how
# Domain::Audit::Recorder records everything else clinically consequential.
# A site is considered promoted iff it has at least one row with
# `promoted: true` (no demotion workflow exists yet — out of scope here).
# `override: true` marks a dev/demo "promote anyway" decision made without
# the gates actually passing (design decision #3) — always distinguishable
# from a real gate-passing promotion in the audit trail.
class CreateRiskModelPromotions < ActiveRecord::Migration[7.2]
  def change
    create_table :risk_model_promotions do |t|
      t.bigint :site_ref, null: false
      t.bigint :decided_by, null: false
      t.integer :version, null: false
      t.jsonb :gate_results, null: false, default: {}
      t.boolean :gates_met, null: false, default: false
      t.boolean :override, null: false, default: false
      t.boolean :promoted, null: false, default: false

      t.timestamps
    end

    add_foreign_key :risk_model_promotions, :sites, column: :site_ref
    add_foreign_key :risk_model_promotions, :users, column: :decided_by
    add_index :risk_model_promotions, :site_ref
    add_index :risk_model_promotions, [ :site_ref, :version ], unique: true
  end
end
