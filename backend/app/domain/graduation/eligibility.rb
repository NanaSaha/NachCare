module Domain
  module Graduation
    # "Day-90 graduation" (Section 0 mission summary + Section 8/M6) — the
    # 90 is playbook-verbatim programme duration, not a clinical threshold,
    # so it isn't PLACEHOLDER_CLINICAL (ADR-0008 #4).
    class Eligibility
      MIN_DAYS = 90

      def self.eligible?(episode:)
        new.eligible?(episode: episode)
      end

      def eligible?(episode:)
        age_days(episode) >= MIN_DAYS
      end

      def age_days(episode)
        (Date.current - episode.start_date).to_i
      end
    end
  end
end
