module Domain
  module Risk
    # UC-21: the real gate-evaluation computation, run against whatever
    # data actually exists in the database — never fabricated. In a fresh
    # dev/demo checkout with no real multi-week pilot, this will typically
    # report `insufficient_data: true` and/or a failing gate; that is the
    # correct, honest behavior (design decision #3), not a bug.
    #
    # Three pre-registered gates (UC-21 step 2), computed per site:
    #
    #   1. Earlier median detection than the rules — for every shadow
    #      score that (a) crossed the alert gate and (b) was eventually
    #      linked to a real rules-driven flag (Domain::Risk::OutcomeLinker),
    #      the lead time in days between the score's check-in date and
    #      the linked flag opening is computed; the gate needs a positive
    #      median across enough samples.
    #   2. Alert rate < 0.10 alert-eligible scores per check-in (a
    #      check-in is used as the "patient-day" unit — see ADR-0012 for
    #      why that's an approximation, not literal continuous-enrollment
    #      patient-days).
    #   3. No missed reds — every red rules evaluation with a paired
    #      shadow score should show at least an "elevated" score; reds
    #      predating shadow scoring (no paired score) are excluded from
    #      the count, not fabricated as a pass.
    class PromotionGate
      MIN_LEAD_TIME_SAMPLES = 5
      MIN_ALERT_RATE_CHECKINS = 20
      ALERT_RATE_CEILING = 0.10

      Result = Struct.new(
        :detection_lead_time_median_days, :detection_lead_time_sample_size, :detection_lead_time_met,
        :alert_rate_per_patient_day, :alert_rate_sample_checkins, :alert_rate_met,
        :missed_reds_count, :missed_reds_total_reds, :missed_reds_met,
        :overall_met, :insufficient_data,
        keyword_init: true
      ) do
        def to_h
          super.transform_values { |v| v.is_a?(BigDecimal) ? v.to_f : v }
        end
      end

      def self.evaluate(site:)
        new(site).evaluate
      end

      def initialize(site)
        @site = site
      end

      def evaluate
        lead = detection_lead_time
        alert = alert_rate
        missed = missed_reds

        Result.new(
          detection_lead_time_median_days: lead[:median], detection_lead_time_sample_size: lead[:sample_size],
          detection_lead_time_met: lead[:met],
          alert_rate_per_patient_day: alert[:rate], alert_rate_sample_checkins: alert[:sample_checkins],
          alert_rate_met: alert[:met],
          missed_reds_count: missed[:count], missed_reds_total_reds: missed[:total], missed_reds_met: missed[:met],
          overall_met: lead[:met] && alert[:met] && missed[:met],
          insufficient_data: lead[:insufficient] || alert[:insufficient]
        )
      end

      private

      attr_reader :site

      def episode_ids
        @episode_ids ||= Episode.joins(:patient).where(patients: { site_ref: site.id }).pluck(:id)
      end

      def detection_lead_time
        scored = RiskScore.where(episode_ref: episode_ids, alert_eligible: true, outcome: %w[flag_yellow flag_red])
          .where.not(outcome_evaluated_at: nil)
          .includes(:check_in)

        lead_days = scored.filter_map { |rs| (rs.outcome_evaluated_at.to_date - rs.check_in.effective_date).to_i }

        if lead_days.size < MIN_LEAD_TIME_SAMPLES
          { median: nil, sample_size: lead_days.size, met: false, insufficient: true }
        else
          median = median_of(lead_days)
          { median: median, sample_size: lead_days.size, met: median.positive?, insufficient: false }
        end
      end

      def alert_rate
        total_checkins = CheckIn.where(episode_ref: episode_ids).count
        alert_checkins = RiskScore.where(episode_ref: episode_ids, alert_eligible: true).count

        if total_checkins < MIN_ALERT_RATE_CHECKINS
          { rate: nil, sample_checkins: total_checkins, met: false, insufficient: true }
        else
          rate = alert_checkins.to_f / total_checkins
          { rate: rate.round(4), sample_checkins: total_checkins, met: rate < ALERT_RATE_CEILING, insufficient: false }
        end
      end

      def missed_reds
        total = 0
        missed = 0

        Evaluation.where(episode_ref: episode_ids, severity: "red").where.not(check_in_ref: nil).find_each do |ev|
          rs = RiskScore.find_by(check_in_ref: ev.check_in_ref)
          next unless rs # no shadow score for this check-in (predates the feature) -- excluded, not fabricated

          total += 1
          missed += 1 if rs.score < Scorer::ELEVATED_THRESHOLD
        end

        # Zero paired reds is a legitimate, vacuously-met state (nothing to
        # miss) — deliberately not folded into `insufficient_data` the way
        # gates 1/2 are, since this gate needs no positive examples to be
        # meaningfully evaluated.
        { count: missed, total: total, met: missed.zero? }
      end

      def median_of(values)
        sorted = values.sort
        mid = sorted.size / 2
        sorted.size.odd? ? sorted[mid].to_f : (sorted[mid - 1] + sorted[mid]) / 2.0
      end
    end
  end
end
