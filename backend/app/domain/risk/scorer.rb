module Domain
  module Risk
    # UC-05 / design decision #1: a real, deterministic, fully-explainable
    # STATISTICAL/heuristic trajectory scorer — NOT a trained model, NOT a
    # black box. Standing in for a real trained model exactly the way the
    # escalation ruleset's clinical thresholds stand in for the real SRS
    # content (PLACEHOLDER_CLINICAL, see docs/OPEN_CLINICAL_ITEMS.md #11
    # and ADR-0012). Every weight/threshold below is placeholder content,
    # not a validated clinical value — never claim otherwise in copy.
    #
    # Computes exactly the three signal families UC-23 names:
    #   1. multi-day weight velocity  (does the trend look like fluid
    #      retention building, even though no single-day/window threshold
    #      in the rules engine has fired yet?)
    #   2. symptom-answer drift       (are structured toggle answers
    #      trending worse across recent check-ins, even if no single
    #      answer alone triggers a rule?)
    #   3. adherence gaps             (missed *critical* medication days
    #      across a trailing window, not just today)
    #
    # Deliberately separate from Domain::Escalation::Engine (R2) — reads
    # the same check-in/episode data but through its own read path, never
    # called from inside the rules engine or its evaluation. See
    # Domain::Risk::ShadowPipeline for the call-site wiring.
    class Scorer
      Result = Struct.new(:score, :components, keyword_init: true)

      # --- placeholder weights (sum to 1.0) ---
      WEIGHT_VELOCITY_WEIGHT = 0.5
      SYMPTOM_DRIFT_WEIGHT = 0.3
      ADHERENCE_GAP_WEIGHT = 0.2

      # --- placeholder normalization caps ---
      # A 3-day weight gain of this many kg (or more) maxes out the
      # velocity component at 1.0. Deliberately different from (and looser
      # than) the rules engine's own placeholder weight-gain thresholds in
      # ruleset_v0_1.json — this is a *softer*, earlier-warning signal by
      # design, not a duplicate of the hard rule.
      VELOCITY_WINDOW_DAYS = 3
      VELOCITY_CAP_KG = 1.2

      # Symptom-toggle trend: average true-toggle count over the most
      # recent vs. prior window of this many check-ins.
      SYMPTOM_WINDOW_SIZE = 3
      SYMPTOM_KEYS = %w[breathless_at_rest swelling_increased fatigue_increased].freeze

      # Adherence gap: missed-critical-medication days over this trailing
      # window.
      ADHERENCE_WINDOW_DAYS = 7

      # A score at/above this crosses the (placeholder) promoted alert
      # gate — the UC-23 "AI WATCH" trigger threshold, only ever acted on
      # post-promotion (Domain::Risk::WatchFlagger).
      ALERT_GATE = 0.55
      # A softer threshold used only by Domain::Risk::PromotionGate's
      # "no missed reds" check (gate 3) — did the shadow score show *any*
      # meaningful elevation on a trajectory that the rules engine called
      # red, even if it never crossed the full alert gate.
      ELEVATED_THRESHOLD = 0.35

      def self.score(episode:, check_in:)
        new(episode:, check_in:).score
      end

      def initialize(episode:, check_in:)
        @episode = episode
        @check_in = check_in
      end

      def score
        components = {
          "weight_velocity" => weight_velocity_component,
          "symptom_drift" => symptom_drift_component,
          "adherence_gap" => adherence_gap_component
        }

        raw = components["weight_velocity"] * WEIGHT_VELOCITY_WEIGHT +
          components["symptom_drift"] * SYMPTOM_DRIFT_WEIGHT +
          components["adherence_gap"] * ADHERENCE_GAP_WEIGHT

        Result.new(score: raw.clamp(0.0, 1.0).round(4), components: components)
      end

      private

      attr_reader :episode, :check_in

      # check_in is always persisted by the time the scorer runs (see
      # Domain::Risk::ShadowPipeline), so it's already included here.
      def recent_check_ins(limit:)
        episode.check_ins
          .where(effective_date: ..check_in.effective_date)
          .order(effective_date: :desc)
          .limit(limit)
          .to_a
      end

      # Simple delta-over-window (documented choice over a regression
      # slope, ADR-0012): today's weight minus the weight from
      # VELOCITY_WINDOW_DAYS ago, if both are known. Only *gains* count
      # (fluid-retention direction) — a loss contributes nothing to risk
      # here by deliberate scope decision.
      def weight_velocity_component
        today = check_in.weight_kg&.to_f
        return 0.0 if today.nil?

        past_date = check_in.effective_date - VELOCITY_WINDOW_DAYS
        past = episode.check_ins.find_by(effective_date: past_date)&.weight_kg&.to_f
        return 0.0 if past.nil?

        gain = today - past
        return 0.0 if gain <= 0

        (gain / VELOCITY_CAP_KG).clamp(0.0, 1.0)
      end

      # Average count of true symptom toggles over the most recent window
      # vs. the window immediately before it. A rising average (drift
      # upward) contributes to risk; a flat/falling average contributes 0.
      def symptom_drift_component
        ordered = recent_check_ins(limit: SYMPTOM_WINDOW_SIZE * 2)
        recent = ordered.first(SYMPTOM_WINDOW_SIZE)
        prior = ordered[SYMPTOM_WINDOW_SIZE, SYMPTOM_WINDOW_SIZE] || []
        return 0.0 if recent.size < SYMPTOM_WINDOW_SIZE || prior.size < SYMPTOM_WINDOW_SIZE

        recent_avg = recent.sum { |ci| true_symptom_count(ci) }.to_f / recent.size
        prior_avg = prior.sum { |ci| true_symptom_count(ci) }.to_f / prior.size
        drift = recent_avg - prior_avg
        return 0.0 if drift <= 0

        (drift / SYMPTOM_KEYS.size).clamp(0.0, 1.0)
      end

      def true_symptom_count(ci)
        symptoms = ci.symptoms || {}
        SYMPTOM_KEYS.count { |k| symptoms[k] == true }
      end

      # Missed *critical* medication days over the trailing window,
      # proportion of the window. Mirrors Domain::Escalation::ContextBuilder's
      # single-day medications_missed_critical? but summed across days.
      def adherence_gap_component
        critical_ids = active_critical_medication_ids
        return 0.0 if critical_ids.empty?

        window = episode.check_ins
          .where(effective_date: (check_in.effective_date - (ADHERENCE_WINDOW_DAYS - 1))..check_in.effective_date)
          .to_a

        return 0.0 if window.empty?

        missed_days = window.count { |ci| critical_ids.any? { |id| (ci.med_status || {})[id] == "missed" } }
        (missed_days.to_f / ADHERENCE_WINDOW_DAYS).clamp(0.0, 1.0)
      end

      def active_critical_medication_ids
        plan = episode.care_plans.find_by(active: true)
        return [] unless plan

        plan.medications.where(critical: true).pluck(:id).map(&:to_s)
      end
    end
  end
end
