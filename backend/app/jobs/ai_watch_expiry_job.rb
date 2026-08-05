# UC-23 Alternate A2: an open AI WATCH flag with no rules escalation and
# no nurse action auto-closes "resolved-uneventful" after 5 days —
# counted on the false-positive side of the alert-rate budget (UC-21 gate
# 2). Mirrors SlaWatchJob's shape (a scheduled state-marking pass over
# flags whose deadline has passed).
class AiWatchExpiryJob
  include Sidekiq::Job

  def perform
    Flag.where(subtype: "ai_watch", state: %w[open in_progress])
      .where.not(watch_expires_at: nil)
      .where("watch_expires_at < ?", Time.current)
      .find_each do |flag|
        flag.update!(state: "resolved", outcome: "resolved_uneventful", resolved_at: Time.current, watch_expires_at: nil)
        Domain::Risk::OutcomeLinker.link_for_watch_resolution!(flag, outcome: "resolved_uneventful")
        Domain::Flags::Broadcaster.call(flag)
        Domain::Audit::Recorder.record!(actor: :system, action: "flag.ai_watch_expired", entity: flag, payload: {})
      end
  end
end
