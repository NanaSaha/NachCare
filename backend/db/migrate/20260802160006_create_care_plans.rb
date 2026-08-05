class CreateCarePlans < ActiveRecord::Migration[7.2]
  def change
    create_table :care_plans do |t|
      t.bigint :episode_ref, null: false
      t.integer :version, null: false, default: 1
      t.boolean :active, null: false, default: false
      t.jsonb :thresholds, null: false, default: {}
      t.text :diet_rules
      t.jsonb :cadence, null: false, default: {}
      t.bigint :approved_by
      t.datetime :approved_at

      t.timestamps
    end

    add_foreign_key :care_plans, :episodes, column: :episode_ref
    add_foreign_key :care_plans, :users, column: :approved_by
    add_index :care_plans, :episode_ref
    add_index :care_plans, [ :episode_ref, :version ], unique: true
    # At most one active care plan per episode (FR-N8 versioning).
    add_index :care_plans, :episode_ref, unique: true, where: "active = true",
      name: "index_care_plans_on_one_active_per_episode"
  end
end
