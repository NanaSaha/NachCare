require "rails_helper"

RSpec.describe KnowledgeDoc do
  describe "#approve! (FR-N15: two-person approval)" do
    it "does not approve after a single approver" do
      doc = create(:knowledge_doc, status: "draft")
      alice = create(:user)

      approved = doc.approve!(alice)

      expect(approved).to be false
      expect(doc.reload.status).to eq("in_review")
    end

    it "approves once two distinct users have approved" do
      doc = create(:knowledge_doc, status: "draft")
      alice = create(:user)
      bob = create(:user)

      doc.approve!(alice)
      approved = doc.approve!(bob)

      expect(approved).to be true
      expect(doc.reload.status).to eq("approved")
    end

    it "does not count the same user approving twice" do
      doc = create(:knowledge_doc, status: "draft")
      alice = create(:user)

      doc.approve!(alice)
      approved = doc.approve!(alice)

      expect(approved).to be false
      expect(doc.reload.status).to eq("in_review")
    end
  end
end
