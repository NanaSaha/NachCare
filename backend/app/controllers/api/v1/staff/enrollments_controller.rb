module Api
  module V1
    module Staff
      # FR-N10/11: a single cockpit screen, <=8 input fields (initials,
      # birth_year, nyha_class, caregiver display_name/relationship/
      # language, medications), creating Patient + Episode + primary
      # Caregiver + a draft CarePlan (thresholds/cadence are clinical
      # content, formalized later — see CarePlan comment) + one activation
      # code, atomically.
      class EnrollmentsController < ApplicationController
        before_action :authenticate_user!

        def create
          patient = Patient.new(
            patient_params.merge(site_ref: current_user.site_ref, pseudonym_code: generate_pseudonym_code)
          )
          authorize patient

          episode = nil
          caregiver = nil
          generated = nil

          ActiveRecord::Base.transaction do
            patient.save!
            episode = patient.episodes.create!(start_date: Date.current, status: "active")
            caregiver = episode.caregivers.create!(caregiver_params)
            care_plan = episode.care_plans.create!(version: 1, active: false, thresholds: {}, cadence: {})
            medication_names.each { |name| care_plan.medications.create!(name: name, drug: match_drug(name)) }
            generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")
          end

          Domain::Audit::Recorder.record!(
            actor: current_user, action: "episode.enrolled", entity: episode, payload: { caregiver_role: "primary" }
          )

          render json: {
            patient: PatientBlueprint.render_as_hash(patient),
            episode: EpisodeBlueprint.render_as_hash(episode),
            caregiver: CaregiverBlueprint.render_as_hash(caregiver),
            activation_code: {
              code: generated.plaintext_code, role: "primary", expires_at: generated.activation_code.expires_at
            }
          }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
        end

        # Re-renders the printable code sheet on demand. The plaintext code
        # is never persisted (see Domain::Enrollment::Activator), so the
        # client — which received it once, from #create — passes it back
        # in to render; this endpoint does not look it up.
        def code_sheet
          episode = Episode.find(params[:episode_id])
          authorize episode, :show?

          pdf = Domain::Enrollment::CodeSheetPdf.render(
            episode: episode,
            plaintext_code: params[:code].to_s,
            role: params[:role].presence || "primary",
            expires_at: Time.zone.parse(params[:expires_at].to_s) || 14.days.from_now
          )
          send_data pdf, filename: "nachcare-activation-#{episode.id}.pdf", type: "application/pdf", disposition: "inline"
        end

        private

        def patient_params
          params.require(:patient).permit(:initials, :birth_year, :nyha_class)
        end

        def caregiver_params
          params.require(:caregiver).permit(:display_name, :relationship, :language)
        end

        def medication_names
          Array(params[:medications]).map(&:to_s).map(&:strip).reject(&:blank?)
        end

        def match_drug(name)
          Drug.find_by("lower(name) = ?", name.downcase)
        end

        def generate_pseudonym_code
          loop do
            code = "PT-#{SecureRandom.hex(4).upcase}"
            break code unless Patient.exists?(pseudonym_code: code)
          end
        end
      end
    end
  end
end
