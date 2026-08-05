require "rails_helper"

RSpec.describe MissedCheckinScanJob do
  let!(:ruleset) do
    create(:ruleset, version: "scan-test", status: "active", body: {
      "version" => "scan-test",
      "rules" => [
        { "id" => "R-8", "key" => "missed_checkin", "severity" => "yellow",
          "condition" => { "type" => "missed_checkin", "consecutive_days" => 1 } }
      ]
    })
  end

  it "flags an active episode with no check-in today" do
    episode = create(:episode, status: "active")

    expect { described_class.new.perform }.to change(Evaluation, :count).by(1)

    evaluation = Evaluation.last
    expect(evaluation.episode_ref).to eq(episode.id)
    expect(evaluation.severity).to eq("yellow")
    expect(Flag.where(episode_ref: episode.id)).to be_present
  end

  it "does not flag an episode that already checked in today" do
    episode = create(:episode, status: "active")
    caregiver = create(:caregiver, episode: episode)
    create(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current)

    described_class.new.perform

    evaluation = Evaluation.find_by(episode_ref: episode.id)
    expect(evaluation.severity).to eq("green")
    expect(Flag.where(episode_ref: episode.id)).to be_empty
  end

  it "skips non-active episodes (graduated/withdrawn/deceased)" do
    create(:episode, status: "graduated")

    expect { described_class.new.perform }.not_to change(Evaluation, :count)
  end

  it "scans every active episode independently" do
    create_list(:episode, 3, status: "active")

    expect { described_class.new.perform }.to change(Evaluation, :count).by(3)
  end
end
