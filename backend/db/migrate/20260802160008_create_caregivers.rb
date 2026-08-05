class CreateCaregivers < ActiveRecord::Migration[7.2]
  def change
    create_table :caregivers, id: :uuid do |t|
      t.bigint :episode_ref, null: false
      t.string :display_name, null: false
      t.string :relationship, null: false
      t.string :language, null: false, default: "en"
      t.time :notification_time
      t.text :contact # encrypted (Active Record encryption)
      t.string :device_token_digest
      t.string :pin_digest
      t.jsonb :push_subscription, null: false, default: {}

      t.timestamps
    end

    add_foreign_key :caregivers, :episodes, column: :episode_ref
    add_index :caregivers, :episode_ref
    add_index :caregivers, :device_token_digest, unique: true
  end
end
