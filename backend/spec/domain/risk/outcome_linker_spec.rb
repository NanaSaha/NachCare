require "rails_helper"

RSpec.describe Domain::Risk::OutcomeLinker do
  let(:episode) { create(:episode) }

  describe ".link_for_flag!" do
    it "tags unlinked shadow scores in the trailing window with the eventual rules outcome" do
      old = create(:risk_score, episode: episode, outcome: nil, created_at: 20.days.ago)
      in_window = create(:risk_score, episode: episode, outcome: nil, created_at: 5.days.ago)
      already_linked = create(:risk_score, episode: episode, outcome: "flag_yellow", outcome_evaluated_at: 1.day.ago, created_at: 5.days.ago)
      flag = create(:flag, episode: episode, severity: "red", opened_at: Time.current)

      described_class.link_for_flag!(flag)

      expect(in_window.reload.outcome).to eq("flag_red")
      expect(old.reload.outcome).to be_nil # outside the 14-day lookback
      expect(already_linked.reload.outcome).to eq("flag_yellow") # untouched
    end
  end

  describe ".link_for_watch_resolution!" do
    it "tags the specific triggering risk_score referenced by ai_watch_meta" do
      risk_score = create(:risk_score, episode: episode, outcome: nil)
      flag = create(:flag, episode: episode, subtype: "ai_watch", ai_watch_meta: { "risk_score_id" => risk_score.id })

      described_class.link_for_watch_resolution!(flag, outcome: "resolved_uneventful")

      expect(risk_score.reload.outcome).to eq("resolved_uneventful")
    end

    it "does nothing when the flag has no linked risk_score" do
      flag = create(:flag, episode: episode, subtype: "ai_watch", ai_watch_meta: {})

      expect { described_class.link_for_watch_resolution!(flag, outcome: "resolved_uneventful") }.not_to raise_error
    end
  end
end
