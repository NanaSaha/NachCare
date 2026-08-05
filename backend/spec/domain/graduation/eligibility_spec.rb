require "rails_helper"

RSpec.describe Domain::Graduation::Eligibility do
  describe "#eligible?" do
    it "is not eligible before day 90" do
      episode = create(:episode, start_date: 89.days.ago.to_date)
      expect(described_class.eligible?(episode: episode)).to be false
    end

    it "is eligible exactly at day 90" do
      episode = create(:episode, start_date: 90.days.ago.to_date)
      expect(described_class.eligible?(episode: episode)).to be true
    end

    it "stays eligible well beyond day 90" do
      episode = create(:episode, start_date: 200.days.ago.to_date)
      expect(described_class.eligible?(episode: episode)).to be true
    end
  end
end
