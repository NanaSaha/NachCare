class CreateAssistantTurns < ActiveRecord::Migration[7.2]
  def change
    create_table :assistant_turns do |t|
      t.bigint :conversation_ref, null: false
      t.string :role, null: false
      t.text :content # encrypted (Active Record encryption)
      t.jsonb :retrieval_refs, null: false, default: []
      t.jsonb :guardrail_verdicts, null: false, default: {}
      t.boolean :routed, null: false, default: false
      t.boolean :emergency_detected, null: false, default: false

      t.timestamps
    end

    add_foreign_key :assistant_turns, :assistant_conversations, column: :conversation_ref
    add_index :assistant_turns, :conversation_ref

    add_check_constraint :assistant_turns, "role IN ('caregiver','assistant')", name: "assistant_turns_role_check"
  end
end
