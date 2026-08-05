module Domain
  module NurseAlerts
    # Product-owner feedback item #4 (ADR-0011): a real cross-app alert so a
    # nurse sees caregiver activity from anywhere in the cockpit, not only
    # when the exact right patient-detail page happens to already be open
    # (that's `CareActivityChannel`/`Domain::CareActivity::Broadcaster`,
    # ADR-0010 — one stream per episode). This broadcaster streams one
    # channel per *site* (mirrors `Domain::Flags::Broadcaster`'s scope, not
    # `CareActivity`'s), because the target UI is the persistent nav bell
    # that's visible on every cockpit screen for every nurse at that site.
    #
    # Payload is deliberately thin — no weight/symptom/dose values, just
    # "what kind of thing happened, for which patient, when" — since its
    # only job is a lightweight badge/list, not clinical detail (a nurse
    # who opens the item navigates to the patient-detail page, which
    # already renders full detail via the existing, unrelated
    # CareActivityChannel/PatientDetailBlueprint). Not a strict R5
    # requirement here (this channel is staff-only/authenticated, same as
    # CareActivityChannel, which does include clinical values) — a
    # deliberately conservative choice for a notification-shaped payload,
    # not a compliance requirement.
    module Broadcaster
      def self.check_in!(check_in)
        broadcast_for(check_in.episode, type: "check_in", occurred_at: check_in.submitted_at)
      end

      def self.dose!(dose)
        broadcast_for(dose.medication.care_plan.episode, type: "medication_dose", occurred_at: dose.taken_at || dose.updated_at, extra: { status: dose.status })
      end

      def self.message!(message)
        broadcast_for(message.episode, type: "caregiver_message", occurred_at: message.created_at)
      end

      def self.broadcast_for(episode, type:, occurred_at:, extra: {})
        patient = episode.patient
        payload = {
          type: type, episode_ref: episode.id, patient_id: patient.id,
          pseudonym_code: patient.pseudonym_code, initials: patient.initials,
          occurred_at: occurred_at
        }.merge(extra)

        ActionCable.server.broadcast("nurse_alerts_site_#{patient.site_ref}", payload)
        payload
      end
    end
  end
end
