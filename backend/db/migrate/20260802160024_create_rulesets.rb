class CreateRulesets < ActiveRecord::Migration[7.2]
  def change
    create_table :rulesets do |t|
      t.string :version, null: false
      t.jsonb :body, null: false
      t.string :status, null: false, default: "draft"
      t.bigint :approved_by
      t.datetime :approved_at

      t.timestamps
    end

    add_foreign_key :rulesets, :users, column: :approved_by
    add_index :rulesets, :version, unique: true

    add_check_constraint :rulesets, "status IN ('draft','shadow','active','retired')", name: "rulesets_status_check"

    # "Add DB constraint: at most one active ruleset" (Section 5).
    add_index :rulesets, :status, unique: true, where: "status = 'active'",
      name: "index_rulesets_on_one_active"
  end
end
