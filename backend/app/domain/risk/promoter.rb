module Domain
  module Risk
    # UC-21 step 3: the real MD/ADM-facing promotion decision. Always
    # re-runs Domain::Risk::PromotionGate fresh server-side (never trusts
    # client-sent numbers). `override` (design decision #3) lets an
    # authorized MD/ADM promote anyway when the gates aren't met — a
    # dev/demo-only escape hatch, always distinguishable in the audit
    # trail (`RiskModelPromotion#override`) from a real gate-passing
    # promotion.
    class Promoter
      def self.decide!(site:, decided_by:, override: false)
        new(site, decided_by, override).decide!
      end

      def initialize(site, decided_by, override)
        @site = site
        @decided_by = decided_by
        @override = !!override
      end

      def decide!
        gate_result = PromotionGate.evaluate(site: site)
        gates_met = gate_result.overall_met
        used_override = override && !gates_met
        promoted = gates_met || used_override

        record = RiskModelPromotion.create!(
          site: site, decider: decided_by, version: RiskModelPromotion.next_version_for(site),
          gate_results: gate_result.to_h, gates_met: gates_met, override: used_override, promoted: promoted
        )

        Domain::Audit::Recorder.record!(
          actor: decided_by, action: "risk_model.promotion_decided", entity: record,
          payload: { site_ref: site.id, promoted: promoted, override: used_override, gates_met: gates_met }
        )

        record
      end

      private

      attr_reader :site, :decided_by, :override
    end
  end
end
