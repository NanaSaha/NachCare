require "rails_helper"

RSpec.describe AiWatchExpiryJob do
  let(:episode) { create(:episode) }
  let(:risk_score) { create(:risk_score, episode: episode, outcome: nil) }

  it "auto-resolves an open ai_watch flag past its expiry as resolved-uneventful" do
    flag = create(:flag, episode: episode, subtype: "ai_watch", state: "open", watch_expires_at: 1.minute.ago,
      ai_watch_meta: { "risk_score_id" => risk_score.id })

    described_class.new.perform

    flag.reload
    expect(flag.state).to eq("resolved")
    expect(flag.outcome).to eq("resolved_uneventful")
    expect(flag.watch_expires_at).to be_nil
    expect(risk_score.reload.outcome).to eq("resolved_uneventful")
  end

  it "does not touch a watch flag before its expiry" do
    flag = create(:flag, episode: episode, subtype: "ai_watch", state: "open", watch_expires_at: 1.hour.from_now)

    described_class.new.perform

    expect(flag.reload.state).to eq("open")
  end

  it "does not touch a non-ai_watch flag even with a stray watch_expires_at" do
    flag = create(:flag, episode: episode, subtype: "clinical", state: "open", watch_expires_at: 1.minute.ago)

    described_class.new.perform

    expect(flag.reload.state).to eq("open")
  end

  it "does not touch an already-resolved ai_watch flag" do
    flag = create(:flag, episode: episode, subtype: "ai_watch", state: "resolved", watch_expires_at: 1.minute.ago)

    expect { described_class.new.perform }.not_to raise_error
    expect(flag.reload.state).to eq("resolved")
  end
end
