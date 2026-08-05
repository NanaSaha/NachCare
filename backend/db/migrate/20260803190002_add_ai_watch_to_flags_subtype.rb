# UC-23: a new predictive flag class ("AI WATCH") alongside the existing
# clinical/adherence/manual subtypes. Extends the existing check
# constraint rather than forking a parallel flag table (design decision
# #4/#5 in the task brief) — AI WATCH flags flow through the exact same
# `Domain::Flags::Lifecycle`/SLA/broadcaster machinery, just with no SLA
# deadline (never set for this subtype, see Lifecycle) and a separate
# `watch_expires_at` (next migration) for its 5-day auto-expiry.
class AddAiWatchToFlagsSubtype < ActiveRecord::Migration[7.2]
  def up
    remove_check_constraint :flags, name: "flags_subtype_check"
    add_check_constraint :flags, "subtype IN ('clinical','adherence','manual','ai_watch')", name: "flags_subtype_check"
  end

  def down
    remove_check_constraint :flags, name: "flags_subtype_check"
    add_check_constraint :flags, "subtype IN ('clinical','adherence','manual')", name: "flags_subtype_check"
  end
end
