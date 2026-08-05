module Domain
  module Risk
    # UC-05 / UC-21: backfills the "eventual outcome" third of the
    # (rules-verdict, risk-score, eventual-outcome) training triple, once
    # it becomes knowable. Two distinct sources of "eventual outcome":
    #
    # 1. `link_for_flag!` — a real rules-driven flag opened (or a
    #    predictive AI WATCH escalated into one) within the trailing
    #    window: every still-unlinked shadow score in that window gets
    #    tagged with what the rules engine eventually did.
    # 2. `link_for_watch_resolution!` — the nurse's own decision (or the
    #    5-day auto-expiry) on a specific AI WATCH flag tags that flag's
    #    own triggering risk_score directly — UC-23 step 7's "nurse's
    #    accept/intervene/dismiss decision is a training label."
    class OutcomeLinker
      LOOKBACK_DAYS = 14

      def self.link_for_flag!(flag)
        new(flag).link_for_flag!
      end

      def self.link_for_watch_resolution!(flag, outcome:)
        new(flag).link_for_watch_resolution!(outcome: outcome)
      end

      def initialize(flag)
        @flag = flag
      end

      def link_for_flag!
        outcome = flag.severity == "red" ? "flag_red" : "flag_yellow"
        window_start = flag.opened_at - LOOKBACK_DAYS.days

        RiskScore.where(episode_ref: flag.episode_ref, outcome: nil)
          .where(created_at: window_start..flag.opened_at)
          .update_all(outcome: outcome, outcome_evaluated_at: Time.current)
      end

      def link_for_watch_resolution!(outcome:)
        risk_score_id = (flag.ai_watch_meta || {})["risk_score_id"]
        return unless risk_score_id

        RiskScore.where(id: risk_score_id, outcome: nil).update_all(outcome: outcome, outcome_evaluated_at: Time.current)
      end

      private

      attr_reader :flag
    end
  end
end
