module Api
  module V1
    module Staff
      # Care plans are versioned, never mutated in place (Section 5:
      # `care_plans.version`, at-most-one-`active`-per-episode). "Editing"
      # means creating a new version and deactivating the old one.
      class CarePlansController < ApplicationController
        before_action :authenticate_user!

        def create
          episode = Episode.find(params[:episode_id])
          previous = episode.care_plans.find_by(active: true)

          new_plan = episode.care_plans.new
          authorize new_plan, :create?, policy_class: CarePlanPolicy

          if thresholds_param.present? && !CarePlanPolicy.new(current_user, new_plan).update_thresholds?
            return render json: { error: "forbidden", detail: "only a physician can change clinical thresholds" }, status: :forbidden
          end

          ActiveRecord::Base.transaction do
            previous&.update!(active: false)

            new_plan.assign_attributes(
              version: (episode.care_plans.maximum(:version) || 0) + 1,
              active: true,
              diet_rules: params[:diet_rules].presence || previous&.diet_rules,
              # Product-owner request (post-M7, ADR-0010): nurse-authored home
              # care instructions, same permission level and carry-forward
              # contract as diet_rules (FR-N8 only gates `thresholds`).
              care_instructions: params[:care_instructions].presence || previous&.care_instructions,
              cadence: params[:cadence].presence || previous&.cadence || {},
              thresholds: thresholds_param.presence || previous&.thresholds || {}
            )
            new_plan.save!

            if params[:medications].present?
              Array(params[:medications]).each do |med|
                new_plan.medications.create!(
                  name: med[:name], critical: ActiveModel::Type::Boolean.new.cast(med[:critical]),
                  drug_ref: med[:drug_id], schedule: med[:schedule].presence || {}
                )
              end
            elsif previous
              # ADR-0010: medications had no carry-forward fallback before
              # this change — every prior field (diet_rules/cadence/
              # thresholds) falls back to the previous version when omitted,
              # but an edit that only touched diet_rules used to silently
              # drop every medication off the new version. Fixed here to
              # match the established fallback pattern.
              previous.medications.each do |med|
                new_plan.medications.create!(name: med.name, critical: med.critical, drug_ref: med.drug_ref, schedule: med.schedule)
              end
            end
          end

          Domain::Audit::Recorder.record!(
            actor: current_user, action: "care_plan.versioned", entity: new_plan,
            payload: { version: new_plan.version, thresholds_changed: thresholds_param.present? }
          )

          render json: {
            id: new_plan.id, version: new_plan.version, diet_rules: new_plan.diet_rules,
            care_instructions: new_plan.care_instructions, thresholds: new_plan.thresholds, cadence: new_plan.cadence,
            medications: new_plan.medications.map { |m| { id: m.id, name: m.name, critical: m.critical, schedule: m.schedule } }
          }, status: :created
        end

        private

        def thresholds_param
          params[:thresholds]
        end
      end
    end
  end
end
