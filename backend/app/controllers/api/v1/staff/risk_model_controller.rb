module Api
  module V1
    module Staff
      # UC-21: MD/ADM-gated shadow-model promotion, per site.
      class RiskModelController < ApplicationController
        before_action :authenticate_user!
        before_action :set_site

        def show
          authorize @site, :show?, policy_class: RiskModelPromotionPolicy

          render json: {
            site_id: @site.id,
            promoted: @site.ai_watch_promoted?,
            gate_evaluation: Domain::Risk::PromotionGate.evaluate(site: @site).to_h,
            history: @site.risk_model_promotions.order(version: :desc).map { |r| promotion_json(r) }
          }, status: :ok
        end

        # `override` (design decision #3): an explicit, clearly-labeled
        # dev/demo escape hatch when the gates aren't met. Always
        # re-evaluates the gates server-side first (Domain::Risk::Promoter) —
        # never trusts a client-sent verdict.
        def promote
          authorize @site, :promote?, policy_class: RiskModelPromotionPolicy

          record = Domain::Risk::Promoter.decide!(
            site: @site, decided_by: current_user, override: ActiveModel::Type::Boolean.new.cast(params[:override]) || false
          )
          render json: promotion_json(record), status: :created
        end

        private

        def set_site
          @site = ::Site.find(params[:site_id])
        end

        def promotion_json(record)
          {
            id: record.id, version: record.version, gates_met: record.gates_met, override: record.override,
            promoted: record.promoted, gate_results: record.gate_results, decided_by: record.decided_by,
            created_at: record.created_at
          }
        end
      end
    end
  end
end
