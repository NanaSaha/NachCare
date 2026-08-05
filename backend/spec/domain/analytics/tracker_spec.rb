require "rails_helper"

RSpec.describe Domain::Analytics::Tracker do
  describe ".track!" do
    it "records an analytics_event keyed by the episode's patient pseudonym, never a raw id (R5)" do
      patient = create(:patient, pseudonym_code: "PT-TRACK-1")
      episode = create(:episode, patient: patient)

      event = described_class.track!(episode: episode, name: "content_item.completed", properties: { "content_item_ref" => 42 })

      expect(event).to be_persisted
      expect(event.episode_pseudonym_ref).to eq("PT-TRACK-1")
      expect(event.name).to eq("content_item.completed")
      expect(event.properties).to eq({ "content_item_ref" => 42 })
      expect(event.occurred_at).to be_present
    end
  end
end
