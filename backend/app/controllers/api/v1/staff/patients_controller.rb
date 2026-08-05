module Api
  module V1
    module Staff
      class PatientsController < ApplicationController
        before_action :authenticate_user!

        def index
          patients = policy_scope(Patient)
          render json: PatientBlueprint.render(patients), status: :ok
        end

        def show
          patient = Patient.find(params[:id])
          authorize patient

          # Audit-log surfacing (Section 8/M3): "who viewed" — every patient
          # detail view is recorded, not just clinical actions.
          Domain::Audit::Recorder.record!(actor: current_user, action: "patient.viewed", entity: patient, payload: {})

          render json: PatientDetailBlueprint.render_as_hash(patient), status: :ok
        end
      end
    end
  end
end
