require "rails_helper"

RSpec.describe Domain::Risk::TrendSummarizer do
  let(:episode) { create(:episode) }

  def score_at(value, days_ago)
    ci = create(:check_in, episode: episode, effective_date: Date.current - days_ago)
    create(:risk_score, episode: episode, check_in: ci, score: value, created_at: days_ago.days.ago)
  end

  it "returns nil with fewer than 2 scores" do
    score_at(0.2, 5)
    expect(described_class.for_episode(episode)).to be_nil
  end

  it "reports rising when the recent average is meaningfully higher" do
    score_at(0.1, 5)
    score_at(0.6, 1)

    expect(described_class.for_episode(episode)).to eq("rising")
  end

  it "reports improving when the recent average is meaningfully lower" do
    score_at(0.6, 5)
    score_at(0.1, 1)

    expect(described_class.for_episode(episode)).to eq("improving")
  end

  it "reports stable when the change is within the noise threshold" do
    score_at(0.3, 5)
    score_at(0.31, 1)

    expect(described_class.for_episode(episode)).to eq("stable")
  end
end
