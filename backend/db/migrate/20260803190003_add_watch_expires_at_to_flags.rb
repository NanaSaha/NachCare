# UC-23 Alternate A2: an open AI WATCH flag with no rules escalation and
# no nurse action auto-closes "resolved-uneventful" after 5 days. Only
# ever set for subtype "ai_watch" — every other subtype's lifecycle is
# unaffected (nil column, no behavior change).
class AddWatchExpiresAtToFlags < ActiveRecord::Migration[7.2]
  def change
    add_column :flags, :watch_expires_at, :datetime
    add_index :flags, :watch_expires_at
  end
end
