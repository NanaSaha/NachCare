require "rails_helper"

RSpec.describe Domain::Risk::WatchOutcomes do
  let(:episode) { create(:episode) }
  let(:risk_score) { create(:risk_score, episode: episode, outcome: nil) }
  let(:flag) do
    create(:flag, episode: episode, subtype: "ai_watch", state: "open", watch_expires_at: 5.days.from_now,
      ai_watch_meta: { "risk_score_id" => risk_score.id })
  end

  it "ignores non-ai_watch flags" do
    clinical_flag = create(:flag, episode: episode, subtype: "clinical")
    expect { described_class.apply!(flag: clinical_flag, outcome: "dismiss_false_positive") }
      .not_to change { clinical_flag.reload.watch_expires_at }
  end

  it "accept_and_watch tightens (never extends) the expiry window" do
    described_class.apply!(flag: flag, outcome: "accept_and_watch")

    expect(flag.reload.watch_expires_at).to be_within(1.minute).of(2.days.from_now)
  end

  it "accept_and_intervene clears the auto-expiry" do
    described_class.apply!(flag: flag, outcome: "accept_and_intervene")

    expect(flag.reload.watch_expires_at).to be_nil
  end

  it "dismiss_false_positive clears expiry and labels the risk_score as resolved_uneventful" do
    described_class.apply!(flag: flag, outcome: "dismiss_false_positive")

    expect(flag.reload.watch_expires_at).to be_nil
    expect(risk_score.reload.outcome).to eq("resolved_uneventful")
  end

  it "does nothing for an unrecognized outcome" do
    expect { described_class.apply!(flag: flag, outcome: "something_else") }
      .not_to change { flag.reload.watch_expires_at }
  end
end
