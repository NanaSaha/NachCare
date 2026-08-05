class CreateAiCalls < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_calls do |t|
      t.string :task, null: false
      t.string :provider, null: false
      t.string :model
      t.string :status, null: false, default: "success" # success|degraded|failed
      t.string :prompt_sha256, null: false
      t.string :response_sha256
      t.integer :latency_ms
      t.integer :tokens_prompt
      t.integer :tokens_completion
      t.jsonb :guardrail_verdicts, null: false, default: {}
      t.text :content # encrypted: prompt+response, purged on caregiver deletion (AI-11)
      t.uuid :caregiver_ref
      t.bigint :episode_ref
      t.bigint :conversation_ref

      t.timestamps
    end

    add_foreign_key :ai_calls, :episodes, column: :episode_ref
    add_foreign_key :ai_calls, :caregivers, column: :caregiver_ref
    add_foreign_key :ai_calls, :assistant_conversations, column: :conversation_ref
    add_index :ai_calls, :task
    add_index :ai_calls, :caregiver_ref
    add_index :ai_calls, :episode_ref
    add_index :ai_calls, :created_at

    add_check_constraint :ai_calls, "status IN ('success','degraded','failed')", name: "ai_calls_status_check"
  end
end
