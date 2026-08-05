module Api
  module V1
    module Caregiver
      # Caregiver requirement #3 / #5 (post-M7, ADR-0010): "today's care
      # tasks" — one entry per scheduled dose slot (medication x time),
      # independent of the once-daily check-in wizard. `index` computes the
      # list from the active care plan's medications' `schedule` (never
      # pre-populated), overlaying any `MedicationDose` rows that already
      # exist for the requested date. `create` is an idempotent upsert
      # keyed on medication+date+time (find_or_initialize_by), so marking
      # the same dose taken twice, or correcting taken->missed, is safe.
      class MedicationDosesController < ApplicationController
        include CaregiverAuthenticatable

        def index
          date = parse_date(params[:date]) || Date.current
          medications = active_medications

          tasks = medications.flat_map { |med| tasks_for(med, date) }.sort_by { |t| t[:scheduled_time] }

          render json: { date: date, tasks: tasks }, status: :ok
        end

        def create
          medication = active_medications.find { |m| m.id == params[:medication_id].to_i }
          return render json: { error: "not_found" }, status: :not_found unless medication

          scheduled_date = parse_date(params[:scheduled_date])
          scheduled_time = params[:scheduled_time].to_s
          status = params[:status].to_s

          unless scheduled_date && scheduled_time.match?(Medication::TIME_FORMAT) && MedicationDose::STATUSES.include?(status) && status != "pending"
            return render json: { error: "invalid_params" }, status: :unprocessable_content
          end

          dose = MedicationDose.find_or_initialize_by(medication_ref: medication.id, scheduled_date: scheduled_date, scheduled_time: scheduled_time)
          dose.caregiver_ref = current_caregiver.id
          dose.status = status
          dose.taken_at = status == "taken" ? Time.current : nil
          dose.save!

          Domain::Audit::Recorder.record!(
            actor: current_caregiver, action: "medication_dose.recorded", entity: dose, payload: { status: status }
          )
          Domain::Analytics::Tracker.track!(episode: current_caregiver.episode, name: "medication_dose.recorded", properties: { status: status })
          Domain::CareActivity::Broadcaster.dose!(dose)
          Domain::NurseAlerts::Broadcaster.dose!(dose)

          render json: dose_json(dose, medication), status: :created
        end

        private

        def active_medications
          current_caregiver.episode.care_plans.find_by(active: true)&.medications || []
        end

        def tasks_for(medication, date)
          existing = MedicationDose.where(medication_ref: medication.id, scheduled_date: date).index_by { |d| d.scheduled_time.strftime("%H:%M") }

          medication.schedule_times.map do |time|
            dose = existing[time]
            {
              medication_id: medication.id, medication_name: medication.name, critical: medication.critical,
              instructions: medication.schedule_instructions, scheduled_date: date, scheduled_time: time,
              status: dose&.status || "pending", dose_id: dose&.id, taken_at: dose&.taken_at
            }
          end
        end

        def dose_json(dose, medication)
          {
            id: dose.id, medication_id: medication.id, medication_name: medication.name,
            scheduled_date: dose.scheduled_date, scheduled_time: dose.scheduled_time.strftime("%H:%M"),
            status: dose.status, taken_at: dose.taken_at
          }
        end

        def parse_date(value)
          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
