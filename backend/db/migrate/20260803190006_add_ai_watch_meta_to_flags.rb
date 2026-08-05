# UC-23 Alternate A1 / design decision #5: preserves an AI WATCH flag's
# triggering risk score (id, score, component breakdown, opened_at) so
# that if it later escalates in place into a real rules-fired flag
# (Domain::Flags::Lifecycle#upgrade), that history/context survives on
# the resulting flag rather than being discarded.
class AddAiWatchMetaToFlags < ActiveRecord::Migration[7.2]
  def change
    add_column :flags, :ai_watch_meta, :jsonb, null: false, default: {}
  end
end
