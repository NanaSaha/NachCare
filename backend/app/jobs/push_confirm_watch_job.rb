# RED chain (Section 8/M4): push -> unconfirmed 5 min -> SMS + cockpit
# escalation task. Runs every minute; any red_escalation push still "sent"
# (never received a push-received confirm beacon from the service worker)
# past the 5-minute window gets marked failed and escalated to SMS.
class PushConfirmWatchJob
  include Sidekiq::Job

  def perform
    cutoff = Domain::Notifications::FallbackChain::RED_CONFIRM_WINDOW.ago

    NotificationAttempt.where(kind: "red_escalation", channel: "webpush", state: "sent")
      .where("created_at < ?", cutoff)
      .find_each do |attempt|
        attempt.update!(state: "failed")
        Domain::Notifications::FallbackChain.escalate_unconfirmed_red!(flag: attempt.flag) if attempt.flag
      end
  end
end
