module Api
  module V1
    module Caregiver
      # Trends (Section 8/M6, ADR-0008 #6): up to the last min(episode_age,
      # 90) days of check-in history — weight series, per-day symptom
      # count, and adherence percentage from med_status. Distinct from the
      # escalation engine's 14-day *evaluation* context window (different
      # purpose: caregiver-facing history, not engine input).
      class TrendsController < ApplicationController
        include CaregiverAuthenticatable

        WINDOW_DAYS = 90

        def show
          episode = current_caregiver.episode
          age_days = (Date.current - episode.start_date).to_i
          window_start = [ age_days, WINDOW_DAYS ].min.days.ago.to_date

          check_ins = episode.check_ins.where(effective_date: window_start..Date.current).order(:effective_date)

          render json: {
            window_days: [ age_days, WINDOW_DAYS ].min,
            points: check_ins.map { |ci| point_json(ci) }
          }, status: :ok
        end

        private

        def point_json(check_in)
          symptoms = check_in.symptoms || {}
          med_status = check_in.med_status || {}
          taken = med_status.values.count { |v| v == "taken" }

          {
            effective_date: check_in.effective_date,
            weight_kg: check_in.weight_kg,
            symptom_count: symptoms.values.count { |v| v == true },
            adherence_pct: med_status.empty? ? nil : ((taken.to_f / med_status.size) * 100).round
          }
        end
      end
    end
  end
end
