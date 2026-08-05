module Api
  module V1
    module Caregiver
      # Product-owner feedback item #1 (post-M7, ADR-0013): "tap a task/
      # medication/note on Home, get an AI explanation grounded in what
      # the nurse actually entered." One endpoint, three item types — all
      # scoped to the caregiver's own active care plan (never any id the
      # caregiver could guess belonging to another episode).
      class CarePlanExplanationsController < ApplicationController
        include CaregiverAuthenticatable

        ITEM_TYPES = %w[medication care_instructions diet_rules].freeze

        def create
          item_type = params[:item_type].to_s
          return render json: { error: "invalid_item_type" }, status: :unprocessable_content unless ITEM_TYPES.include?(item_type)

          active_plan = current_caregiver.episode.care_plans.find_by(active: true)
          return render json: { error: "no_active_care_plan" }, status: :not_found unless active_plan

          label, detail = item_label_and_detail(item_type, active_plan)
          return render json: { error: "not_found" }, status: :not_found if label.nil?

          result = Domain::Ai::Gateway.explain_care_plan_item(
            episode: current_caregiver.episode, language: current_caregiver.language,
            item_type: item_type, item_label: label, item_detail: detail
          )

          Domain::Audit::Recorder.record!(
            actor: current_caregiver, action: "care_plan_item.explained", entity: active_plan,
            payload: { item_type: item_type, source: result.source }
          )

          render json: { text: result.text, source: result.source }, status: :ok
        end

        private

        def item_label_and_detail(item_type, active_plan)
          case item_type
          when "medication"
            medication = active_plan.medications.find_by(id: params[:item_id])
            return [ nil, nil ] unless medication

            times = medication.schedule_times
            detail = "Medication: #{medication.name}. " \
                     "Scheduled times: #{times.any? ? times.join(', ') : 'no scheduled times set'}. " \
                     "Nurse's instructions: #{medication.schedule_instructions || 'none given'}."
            [ medication.name, detail ]
          when "care_instructions"
            return [ nil, nil ] if active_plan.care_instructions.blank?

            [ "Home care instructions", active_plan.care_instructions ]
          when "diet_rules"
            return [ nil, nil ] if active_plan.diet_rules.blank?

            [ "Diet", active_plan.diet_rules ]
          end
        end
      end
    end
  end
end
