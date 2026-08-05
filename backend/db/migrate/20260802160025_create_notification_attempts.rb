class CreateNotificationAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :notification_attempts do |t|
      t.string :kind, null: false
      t.string :channel, null: false
      t.string :state, null: false, default: "sent"
      t.uuid :caregiver_ref, null: false
      t.bigint :flag_ref

      t.timestamps
    end

    add_foreign_key :notification_attempts, :caregivers, column: :caregiver_ref
    add_foreign_key :notification_attempts, :flags, column: :flag_ref
    add_index :notification_attempts, :caregiver_ref
    add_index :notification_attempts, :flag_ref
    add_index :notification_attempts, :state

    add_check_constraint :notification_attempts, "channel IN ('webpush','sms','email')", name: "notification_attempts_channel_check"
    add_check_constraint :notification_attempts, "state IN ('sent','confirmed','failed')", name: "notification_attempts_state_check"
  end
end
