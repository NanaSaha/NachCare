class CreateAssistantConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :assistant_conversations do |t|
      t.bigint :episode_ref, null: false
      t.uuid :caregiver_ref, null: false
      t.string :language, null: false, default: "en"
      t.datetime :started_at, null: false

      t.timestamps
    end

    add_foreign_key :assistant_conversations, :episodes, column: :episode_ref
    add_foreign_key :assistant_conversations, :caregivers, column: :caregiver_ref
    add_index :assistant_conversations, :episode_ref
    add_index :assistant_conversations, :caregiver_ref
  end
end
