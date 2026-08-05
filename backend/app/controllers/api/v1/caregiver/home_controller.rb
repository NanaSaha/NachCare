module Api
  module V1
    module Caregiver
      # Everything the check-in wizard needs before the caregiver starts:
      # their own profile, the active care plan's medications (step 2, per-
      # item toggles), and their last submitted weight (step 1's trend
      # chip). One call, not one per concern, since all of it is needed
      # up-front before the wizard can render its first screen.
      class HomeController < ApplicationController
        include CaregiverAuthenticatable

        def show
          episode = current_caregiver.episode
          active_plan = episode.care_plans.find_by(active: true)
          last_check_in = episode.check_ins.where.not(weight_kg: nil).order(effective_date: :desc).first

          render json: {
            caregiver: CaregiverSelfBlueprint.render_as_hash(current_caregiver),
            # Product-owner request (post-M7, ADR-0010): everything the
            # nurse/dr uploaded, so the caregiver sees it on login — diet
            # rules and free-text home-care instructions are nurse-authored
            # real content (not system-authored placeholder copy, R1 note),
            # medications now carry their full schedule (times + optional
            # instructions), not just id/name/critical.
            diet_rules: active_plan&.diet_rules,
            care_instructions: active_plan&.care_instructions,
            medications: (active_plan&.medications || []).map do |m|
              { id: m.id, name: m.name, critical: m.critical, schedule: { "times" => m.schedule_times, "instructions" => m.schedule_instructions } }
            end,
            last_weight_kg: last_check_in&.weight_kg,
            last_check_in_date: last_check_in&.effective_date
          }, status: :ok
        end
      end
    end
  end
end
