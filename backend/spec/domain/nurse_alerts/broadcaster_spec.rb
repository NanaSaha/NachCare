require "rails_helper"

RSpec.describe Domain::NurseAlerts::Broadcaster do
  describe ".check_in!" do
    it "broadcasts a thin alert payload to the patient's site stream" do
      check_in = create(:check_in)
      site_ref = check_in.episode.patient.site_ref

      expect(ActionCable.server).to receive(:broadcast).with(
        "nurse_alerts_site_#{site_ref}",
        hash_including(type: "check_in", episode_ref: check_in.episode_ref, patient_id: check_in.episode.patient.id)
      )

      described_class.check_in!(check_in)
    end

    it "does not include clinical values (weight/symptoms) in the payload" do
      check_in = create(:check_in, weight_kg: 71.2, symptoms: { breathless_at_rest: true })

      payload = nil
      allow(ActionCable.server).to receive(:broadcast) { |_stream, data| payload = data }

      described_class.check_in!(check_in)

      expect(payload.keys).not_to include(:weight_kg, :symptoms)
    end
  end

  describe ".dose!" do
    it "broadcasts a medication-dose alert" do
      care_plan = create(:care_plan)
      medication = create(:medication, care_plan: care_plan)
      dose = create(:medication_dose, medication: medication, status: "taken", taken_at: Time.current)
      site_ref = care_plan.episode.patient.site_ref

      expect(ActionCable.server).to receive(:broadcast).with(
        "nurse_alerts_site_#{site_ref}",
        hash_including(type: "medication_dose", status: "taken")
      )

      described_class.dose!(dose)
    end
  end

  describe ".message!" do
    it "broadcasts a caregiver-message alert" do
      episode = create(:episode)
      message = create(:message, episode: episode, sender: "caregiver")
      site_ref = episode.patient.site_ref

      expect(ActionCable.server).to receive(:broadcast).with(
        "nurse_alerts_site_#{site_ref}",
        hash_including(type: "caregiver_message", episode_ref: episode.id)
      )

      described_class.message!(message)
    end
  end
end
