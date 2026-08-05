module Domain
  module Flags
    # SLA deadlines come from the patient's site (sites.sla_red_minutes /
    # sla_yellow_minutes, Section 5 — defaults 30 / 240). Green never has a
    # deadline; there's nothing to act on.
    class Sla
      def self.deadline_for(episode:, severity:, from:)
        new(episode:, severity:, from:).deadline
      end

      def initialize(episode:, severity:, from:)
        @episode = episode
        @severity = severity
        @from = from
      end

      def deadline
        case severity
        when "red" then from + site.sla_red_minutes.minutes
        when "yellow" then from + site.sla_yellow_minutes.minutes
        end
      end

      private

      attr_reader :episode, :severity, :from

      def site
        episode.patient.site
      end
    end
  end
end
