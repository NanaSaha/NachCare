require "rails_helper"

RSpec.describe AiCall do
  describe ".purge_for_caregiver! (AI-11)" do
    it "nils content for every ai_call tied to the caregiver, keeping the row" do
      caregiver = create(:caregiver)
      call = AiCall.create!(task: "assistant", provider: "stub", status: "success", prompt_sha256: "x" * 10, content: "sensitive", caregiver_ref: caregiver.id)

      AiCall.purge_for_caregiver!(caregiver)

      expect(call.reload.content).to be_nil
      expect(AiCall.exists?(call.id)).to be true
    end

    it "does not touch ai_calls for other caregivers" do
      caregiver = create(:caregiver)
      other = create(:caregiver)
      untouched = AiCall.create!(task: "assistant", provider: "stub", status: "success", prompt_sha256: "x" * 10, content: "keep me", caregiver_ref: other.id)

      AiCall.purge_for_caregiver!(caregiver)

      expect(untouched.reload.content).to eq("keep me")
    end
  end
end
