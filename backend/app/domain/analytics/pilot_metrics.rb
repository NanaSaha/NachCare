module Domain
  module Analytics
    # AN-1's "five metrics" (ADR-0009 #1). Computed directly from
    # source-of-truth tables (check_ins, flags, episodes, assistant_turns),
    # not from `analytics_events` — see the ADR for why. Pseudonym/aggregate
    # output only (site id, counts, rates, minutes) — never a patient or
    # caregiver identifier, per R5. Every rate is `nil` (not 0.0) when its
    # denominator is empty, so callers/UI can distinguish "no data yet"
    # from "0%".
    class PilotMetrics
      Result = Struct.new(
        :site_id, :from, :to,
        :checkin_adherence_rate,
        :red_flag_sla_compliance_rate,
        :red_flag_median_time_to_first_action_minutes,
        :program_completion_rate,
        :assistant_safety_routing_rate,
        keyword_init: true
      ) do
        def to_h
          super.transform_values { |v| v.is_a?(Date) ? v.iso8601 : v }
        end
      end

      def self.compute(site:, from:, to:)
        new(site:, from:, to:).compute
      end

      def initialize(site:, from:, to:)
        @site = site
        @from = from
        @to = to
      end

      def compute
        Result.new(
          site_id: site.id, from: from, to: to,
          checkin_adherence_rate: checkin_adherence_rate,
          red_flag_sla_compliance_rate: red_flag_sla_compliance_rate,
          red_flag_median_time_to_first_action_minutes: red_flag_median_time_to_first_action_minutes,
          program_completion_rate: program_completion_rate,
          assistant_safety_routing_rate: assistant_safety_routing_rate
        )
      end

      private

      attr_reader :site, :from, :to

      def site_episodes
        Episode.joins(:patient).where(patients: { site_ref: site.id })
      end

      def site_flags
        Flag.joins(episode: :patient).where(patients: { site_ref: site.id })
      end

      # Metric 1: completed check-in days / expected check-in days, summed
      # across every episode active at some point during [from, to],
      # expected days capped at each episode's own age (an episode that
      # started 5 days ago can't have more than 5 expected days).
      def checkin_adherence_rate
        expected_total = 0
        completed_total = 0

        site_episodes.find_each do |episode|
          window_start = [ from, episode.start_date ].max
          window_end = [ to, Date.current ].min
          next if window_end < window_start

          expected_total += (window_end - window_start).to_i + 1
          completed_total += episode.check_ins
            .where(effective_date: window_start..window_end)
            .distinct.count(:effective_date)
        end

        return nil if expected_total.zero?

        completed_total.to_f / expected_total
      end

      def red_flags_in_window
        site_flags.where(severity: "red").where(opened_at: from.beginning_of_day..to.end_of_day)
      end

      # Metric 2: share of RED flags actioned/resolved within their own
      # sla_deadline_at (breach == false), per Domain::Flags::Sla.
      def red_flag_sla_compliance_rate
        flags = red_flags_in_window
        total = flags.count
        return nil if total.zero?

        flags.where(breach: false).count.to_f / total
      end

      # Metric 3: median minutes from opened_at to first_action_at, RED
      # flags only, excluding flags never yet actioned.
      def red_flag_median_time_to_first_action_minutes
        minutes = red_flags_in_window.where.not(first_action_at: nil)
          .pluck(:opened_at, :first_action_at)
          .map { |opened_at, first_action_at| (first_action_at - opened_at) / 60.0 }
          .sort

        return nil if minutes.empty?

        mid = minutes.size / 2
        minutes.size.odd? ? minutes[mid] : (minutes[mid - 1] + minutes[mid]) / 2.0
      end

      # Metric 4: among episodes old enough to have concluded one way or
      # another (Domain::Graduation::Eligibility's 90-day floor), the share
      # that reached "graduated" vs. withdrawn/deceased/still-open-past-90.
      def program_completion_rate
        eligible = site_episodes.select { |e| Domain::Graduation::Eligibility.eligible?(episode: e) }
        return nil if eligible.empty?

        eligible.count { |e| e.status == "graduated" }.to_f / eligible.size
      end

      # Metric 5: share of assistant-authored turns a guardrail kept off
      # clinical ground (routed or emergency_detected) — see ADR-0009 #1
      # for the framing caveat (this is not a safety-recall claim; that's
      # `rake ai:eval`'s job).
      def assistant_safety_routing_rate
        turns = AssistantTurn.joins(:assistant_conversation)
          .where(assistant_conversations: { episode_ref: site_episodes.select(:id) })
          .where(role: "assistant")
          .where(created_at: from.beginning_of_day..to.end_of_day)

        total = turns.count
        return nil if total.zero?

        turns.where("routed = true OR emergency_detected = true").count.to_f / total
      end
    end
  end
end
