module Domain
  module CareActivity
    # Nurse requirement #3 ("see in realtime updates from the caregiver"),
    # ADR-0010. Same shape as `Domain::Flags::Broadcaster` (M3): raw
    # attributes over ActionCable, one stream per episode (not per site —
    # a nurse only watches this on a patient-detail page that's already
    # scoped to one episode), so the payload doesn't need presentation-layer
    # rendering. Both the live broadcast and the initial-load `Feed` (below)
    # share these payload builders so the cockpit renders identical shapes
    # whether an item arrived live or from the initial fetch.
    module Broadcaster
      def self.check_in!(check_in)
        payload = check_in_payload(check_in)
        broadcast(check_in.episode_ref, payload)
        payload
      end

      def self.dose!(dose)
        payload = dose_payload(dose)
        broadcast(dose.medication.care_plan.episode_ref, payload)
        payload
      end

      def self.check_in_payload(check_in)
        {
          type: "check_in", id: check_in.id, episode_ref: check_in.episode_ref,
          effective_date: check_in.effective_date, occurred_at: check_in.submitted_at,
          weight_kg: check_in.weight_kg,
          # ADR-0011 (feedback item #2): the caregiver's free-text "how is
          # she feeling today" answer (reuses `check_ins.note`) and any
          # attached photo/video URLs, so the same live/initial-load feed
          # that already shows check-ins surfaces these too.
          note: check_in.note,
          photo_urls: check_in.check_in_photos.map { |p| Domain::Media::Url.for(p.image) }.compact
        }
      end

      def self.dose_payload(dose)
        {
          type: "medication_dose", id: dose.id, episode_ref: dose.medication.care_plan.episode_ref,
          medication_name: dose.medication.name, scheduled_date: dose.scheduled_date,
          scheduled_time: dose.scheduled_time.strftime("%H:%M"), status: dose.status,
          occurred_at: dose.taken_at || dose.updated_at
        }
      end

      def self.broadcast(episode_ref, payload)
        ActionCable.server.broadcast("care_activity_episode_#{episode_ref}", payload)
      end
    end
  end
end
