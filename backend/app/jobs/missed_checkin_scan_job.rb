# R-8 (missed_checkin) — the nightly 23:59 scan (Section 7/8). For every
# active episode, runs the escalation engine with check_in: nil so
# Domain::Escalation::ContextBuilder computes consecutive_missed_checkin_days
# from the episode's silence rather than a submitted check-in. Also drives
# the M4 missed-day notification chain (day 1 -> push, day 2+ -> SMS) off
# the same count, so there's one source of truth for "how many days missed."
class MissedCheckinScanJob
  include Sidekiq::Job

  def perform
    Episode.where(status: "active").find_each do |episode|
      result = Domain::Escalation::Processor.process!(episode: episode, check_in: nil)
      missed_days = result.context[:consecutive_missed_checkin_days]
      next unless missed_days.to_i.positive?

      Domain::Notifications::FallbackChain.missed_day!(episode: episode, consecutive_missed_days: missed_days)
    end
  end
end
