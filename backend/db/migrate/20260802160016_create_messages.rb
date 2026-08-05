class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.bigint :episode_ref, null: false
      t.string :sender, null: false
      t.string :template_key
      t.text :body_source, null: false
      t.text :body_translated
      t.string :language, null: false, default: "en"

      t.timestamps
    end

    add_foreign_key :messages, :episodes, column: :episode_ref
    add_index :messages, :episode_ref

    add_check_constraint :messages, "sender IN ('nurse','caregiver','system','ai')", name: "messages_sender_check"
  end
end
