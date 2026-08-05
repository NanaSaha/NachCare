require "rails_helper"

RSpec.describe Domain::Learn::Unlocker do
  describe "#unlocked?" do
    it "unlocks week 1 items on day 0" do
      episode = create(:episode, start_date: Date.current)
      item = create(:content_item, week_no: 1)

      expect(described_class.unlocked?(item: item, episode: episode)).to be true
    end

    it "keeps week 2 items locked before day 7" do
      episode = create(:episode, start_date: 3.days.ago.to_date)
      item = create(:content_item, week_no: 2)

      expect(described_class.unlocked?(item: item, episode: episode)).to be false
    end

    it "unlocks week 2 items from day 7 onward" do
      episode = create(:episode, start_date: 7.days.ago.to_date)
      item = create(:content_item, week_no: 2)

      expect(described_class.unlocked?(item: item, episode: episode)).to be true
    end

    it "unlocks a far-future week once the episode is old enough" do
      episode = create(:episode, start_date: 90.days.ago.to_date)
      item = create(:content_item, week_no: 13)

      expect(described_class.unlocked?(item: item, episode: episode)).to be true
    end
  end
end
