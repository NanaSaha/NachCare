module Domain
  module Risk
    # UC-25: "TRENDS, not raw scores" — an explicit R5 instruction never to
    # leak a raw score or raw clinical value into the population view.
    # Only ever computed/exposed when the episode's site is promoted
    # (enforced by the caller, PatientBlueprint#risk_trend) — a direction
    # only (rising/stable/improving), nothing more granular.
    class TrendSummarizer
      WINDOW_SIZE = 3
      DELTA_THRESHOLD = 0.05
      TRENDS = %w[rising stable improving].freeze

      def self.for_episode(episode)
        new(episode).trend
      end

      def initialize(episode)
        @episode = episode
      end

      def trend
        scores = episode.risk_scores.order(created_at: :desc).limit(WINDOW_SIZE * 2).pluck(:score).map(&:to_f)
        return nil if scores.size < 2

        window = [ WINDOW_SIZE, scores.size / 2 ].min
        recent = scores.first(window)
        prior = scores[window, window]
        return nil if prior.blank?

        delta = (recent.sum / recent.size) - (prior.sum / prior.size)

        if delta > DELTA_THRESHOLD then "rising"
        elsif delta < -DELTA_THRESHOLD then "improving"
        else "stable"
        end
      end

      private

      attr_reader :episode
    end
  end
end
