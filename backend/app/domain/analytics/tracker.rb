module Domain
  module Analytics
    # Section 4 repo layout reserves `app/domain/analytics/tracker.rb`; this
    # is the minimal entry point M6's Learn "completion events" need
    # (ADR-0008 #3). `pilot_metrics.rb` (the AN-1 taxonomy + five pilot
    # metrics) stays M7 scope. Pseudonym-only, per Section 5's
    # `analytics_events` shape and R5 (no PHI) — episodes are referenced by
    # their patient's `pseudonym_code`, never a raw id or name.
    class Tracker
      def self.track!(episode:, name:, properties: {})
        new.track!(episode: episode, name: name, properties: properties)
      end

      def track!(episode:, name:, properties: {})
        AnalyticsEvent.create!(
          episode_pseudonym_ref: episode.patient.pseudonym_code,
          name: name.to_s,
          properties: properties,
          occurred_at: Time.current
        )
      end
    end
  end
end
