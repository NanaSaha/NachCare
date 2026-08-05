# Marks flags breached once their SLA deadline passes without resolution.
# Pure a state-marking pass — the actual "what happens on breach" (cockpit
# escalation task, notification) is M4's concern; this job only sets the
# `breach` flag so the cockpit queue (M3) can surface it.
class SlaWatchJob
  include Sidekiq::Job

  def perform
    Flag.where(state: %w[open in_progress], breach: false)
      .where.not(sla_deadline_at: nil)
      .where("sla_deadline_at < ?", Time.current)
      .update_all(breach: true)
  end
end
