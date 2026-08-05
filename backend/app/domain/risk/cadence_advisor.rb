module Domain
  module Risk
    # UC-24: post-promotion-only cadence-adaptation proposals, built on
    # the same shadow risk-score trend TrendSummarizer computes for UC-25.
    # `refresh!` only ever creates a *pending proposal* — nothing here
    # touches a live care plan. Only `approve!` (a nurse action) ever
    # versions a new CarePlan, per UC-24 step 3 ("the model never silently
    # changes what a family is asked to do").
    class CadenceAdvisor
      MIN_SCORES = 4
      LOW_RISK_CEILING = 0.15
      RISING_FLOOR = 0.35

      TAPER_CADENCE = { "times_per_week" => 3 }.freeze
      DENSIFY_CADENCE = { "times_per_week" => 7, "evening_symptom_check" => true }.freeze

      def self.refresh!(episode)
        new(episode).refresh!
      end

      def initialize(episode)
        @episode = episode
      end

      # Idempotent: never opens a second proposal while one is already
      # pending. Returns the current pending proposal (freshly created or
      # pre-existing), or nil if neither promoted nor enough history nor
      # any signal to propose.
      def refresh!
        return existing_pending if existing_pending
        return nil unless episode.patient.site.ai_watch_promoted?

        scores = episode.risk_scores.order(created_at: :desc).limit(MIN_SCORES).pluck(:score).map(&:to_f)
        return nil if scores.size < MIN_SCORES

        avg = (scores.sum / scores.size).round(3)
        trend = TrendSummarizer.for_episode(episode)

        if avg <= LOW_RISK_CEILING && trend != "rising"
          create_proposal("taper", TAPER_CADENCE, "Stable low-risk trend over the last #{scores.size} check-ins (avg score #{avg}).")
        elsif avg >= RISING_FLOOR || trend == "rising"
          create_proposal("densify", DENSIFY_CADENCE, "Rising risk trend over the last #{scores.size} check-ins (avg score #{avg}).")
        end
      end

      def approve!(proposal, decided_by:)
        raise ArgumentError, "proposal is not pending" unless proposal.status == "pending"

        care_plan = nil
        ActiveRecord::Base.transaction do
          previous = episode.care_plans.find_by(active: true)
          previous&.update!(active: false)

          care_plan = episode.care_plans.create!(
            version: (episode.care_plans.maximum(:version) || 0) + 1, active: true,
            diet_rules: previous&.diet_rules, care_instructions: previous&.care_instructions,
            thresholds: previous&.thresholds || {}, cadence: proposal.proposed_cadence
          )
          previous&.medications&.each do |m|
            care_plan.medications.create!(name: m.name, critical: m.critical, drug_ref: m.drug_ref, schedule: m.schedule)
          end

          proposal.update!(status: "approved", decider: decided_by, decided_at: Time.current)
        end

        Domain::Audit::Recorder.record!(
          actor: decided_by, action: "cadence_proposal.approved", entity: proposal,
          payload: { direction: proposal.direction, care_plan_version: care_plan.version }
        )
        care_plan
      end

      def dismiss!(proposal, decided_by:)
        proposal.update!(status: "dismissed", decider: decided_by, decided_at: Time.current)
        Domain::Audit::Recorder.record!(
          actor: decided_by, action: "cadence_proposal.dismissed", entity: proposal, payload: { direction: proposal.direction }
        )
      end

      private

      attr_reader :episode

      def existing_pending
        @existing_pending ||= episode.cadence_proposals.find_by(status: "pending")
      end

      def create_proposal(direction, cadence, rationale)
        CadenceProposal.create!(episode: episode, direction: direction, proposed_cadence: cadence, rationale: rationale, status: "pending")
      end
    end
  end
end
