module Domain
  module Risk
    # UC-05: the shadow-mode entry point, called as an additional,
    # independent step at every call site of
    # Domain::Escalation::Processor.process! (never from inside the
    # engine/processor itself — see Scorer's header comment and R2). Pairs
    # the heuristic score with the rules verdict for the same check-in and
    # persists it. This NEVER creates a flag and NEVER surfaces in any UI
    # by itself — see Domain::Risk::WatchFlagger for the (post-promotion-
    # only) acting step, invoked separately right after this one.
    class ShadowPipeline
      def self.process!(episode:, check_in:, evaluation:)
        new(episode:, check_in:, evaluation:).process!
      end

      def initialize(episode:, check_in:, evaluation:)
        @episode = episode
        @check_in = check_in
        @evaluation = evaluation
      end

      # No check-in (e.g. the R-8 nightly missed-check-in scan) -> nothing
      # to score; UC-05's trigger is explicitly "every check-in."
      def process!
        return nil if check_in.nil?

        result = Scorer.score(episode: episode, check_in: check_in)
        rules_severity = evaluation&.severity || "green"

        risk_score = RiskScore.create!(
          episode: episode, check_in: check_in, score: result.score, components: result.components,
          rules_severity: rules_severity, alert_eligible: result.score >= Scorer::ALERT_GATE
        )

        Rails.logger.info(
          "[Domain::Risk::ShadowPipeline] shadow score computed episode_ref=#{episode.id} " \
          "score=#{result.score} rules_severity=#{rules_severity} alert_eligible=#{risk_score.alert_eligible} " \
          "(shadow only — not acted on)"
        )

        risk_score
      end

      private

      attr_reader :episode, :check_in, :evaluation
    end
  end
end
