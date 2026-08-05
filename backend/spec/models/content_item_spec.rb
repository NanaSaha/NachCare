require "rails_helper"

RSpec.describe ContentItem do
  describe "#approve! (mirrors FR-N15 two-person approval)" do
    it "does not approve after a single approver" do
      item = create(:content_item, status: "draft")
      alice = create(:user)

      approved = item.approve!(alice)

      expect(approved).to be false
      expect(item.reload.status).to eq("in_review")
    end

    it "approves once two distinct users have approved" do
      item = create(:content_item, status: "draft")
      alice = create(:user)
      bob = create(:user)

      item.approve!(alice)
      approved = item.approve!(bob)

      expect(approved).to be true
      expect(item.reload.status).to eq("approved")
    end

    it "does not count the same user approving twice" do
      item = create(:content_item, status: "draft")
      alice = create(:user)

      item.approve!(alice)
      approved = item.approve!(alice)

      expect(approved).to be false
      expect(item.reload.status).to eq("in_review")
    end
  end

  describe "#variant_for" do
    it "returns the requested language's variant" do
      item = build(:content_item, language_variants: { "en" => { "title" => "EN" }, "de" => { "title" => "DE" } })
      expect(item.variant_for("de")).to eq({ "title" => "DE" })
    end

    it "falls back to english when the language has no variant" do
      item = build(:content_item, language_variants: { "en" => { "title" => "EN" } })
      expect(item.variant_for("tr")).to eq({ "title" => "EN" })
    end

    it "returns an empty hash when even english is missing" do
      item = build(:content_item, language_variants: {})
      expect(item.variant_for("en")).to eq({})
    end
  end

  it "validates kind, week_no, status" do
    item = build(:content_item, kind: "bogus", week_no: 0, status: "bogus")
    expect(item).not_to be_valid
    expect(item.errors[:kind]).to be_present
    expect(item.errors[:week_no]).to be_present
    expect(item.errors[:status]).to be_present
  end
end
