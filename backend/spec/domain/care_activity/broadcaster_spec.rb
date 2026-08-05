require "rails_helper"

RSpec.describe Domain::CareActivity::Broadcaster do
  describe ".check_in!" do
    it "broadcasts a check-in payload to the episode's activity stream" do
      check_in = create(:check_in)

      expect(ActionCable.server).to receive(:broadcast).with(
        "care_activity_episode_#{check_in.episode_ref}",
        hash_including(type: "check_in", id: check_in.id, episode_ref: check_in.episode_ref)
      )

      described_class.check_in!(check_in)
    end

    it "includes the caregiver's note and attached photo urls (ADR-0011)" do
      check_in = create(:check_in, note: "feeling okay today")
      photo = check_in.check_in_photos.new
      photo.image.attach(io: StringIO.new("x" * 10), filename: "test.jpg", content_type: "image/jpeg")
      photo.save!

      payload = described_class.check_in_payload(check_in)

      expect(payload[:note]).to eq("feeling okay today")
      expect(payload[:photo_urls].size).to eq(1)
    end
  end

  describe ".dose!" do
    it "broadcasts a medication-dose payload to the episode's activity stream" do
      care_plan = create(:care_plan)
      medication = create(:medication, care_plan: care_plan, name: "Furosemide")
      dose = create(:medication_dose, medication: medication, status: "taken", taken_at: Time.current)

      expect(ActionCable.server).to receive(:broadcast).with(
        "care_activity_episode_#{care_plan.episode_ref}",
        hash_including(type: "medication_dose", id: dose.id, medication_name: "Furosemide", status: "taken")
      )

      described_class.dose!(dose)
    end
  end
end
