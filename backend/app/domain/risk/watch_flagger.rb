module Domain
  module Risk
    # UC-23: the ONLY place a shadow risk score is allowed to act. Turns a
    # crossed-gate score on an otherwise-green check-in into a new
    # "AI WATCH" flag (subtype ai_watch) — but only when the patient's
    # site has been explicitly promoted (Site#ai_watch_promoted?, UC-21).
    # Pre-promotion this is never called with an eligible outcome in
    # practice (call sites should still gate on promoted? first for
    # clarity/logging), and even if called, `eligible?` below re-checks
    # promotion itself as a second, authoritative gate — shadow mode stays
    # enforced even if a future call site forgets to check.
    class WatchFlagger
      WATCH_EXPIRY_DAYS = 5

      def self.call!(risk_score:)
        new(risk_score).call!
      end

      def initialize(risk_score)
        @risk_score = risk_score
      end

      def call!
        return nil unless eligible?

        flag = Flag.create!(
          episode_ref: episode.id, evaluation_refs: [], severity: "yellow", subtype: "ai_watch",
          state: "open", opened_at: Time.current, sla_deadline_at: nil,
          watch_expires_at: Time.current + WATCH_EXPIRY_DAYS.days,
          ai_watch_meta: {
            "risk_score_id" => risk_score.id, "score" => risk_score.score.to_f,
            "components" => risk_score.components, "opened_at" => Time.current.iso8601
          }
        )

        Domain::Flags::Broadcaster.call(flag)
        Domain::Audit::Recorder.record!(
          actor: :system, action: "flag.ai_watch_opened", entity: flag, payload: { score: risk_score.score.to_f }
        )
        flag
      end

      private

      attr_reader :risk_score

      def episode
        @episode ||= risk_score.episode
      end

      def eligible?
        return false unless risk_score.rules_severity == "green"
        return false unless risk_score.alert_eligible
        return false unless episode.patient.site.ai_watch_promoted?
        return false if Flag.where(episode_ref: episode.id, state: %w[open in_progress]).exists?

        true
      end
    end
  end
end
