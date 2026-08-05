require "rails_helper"

RSpec.describe Domain::Risk::WatchFlagger do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:check_in) { create(:check_in, episode: episode) }

  def eligible_risk_score(**overrides)
    create(:risk_score, episode: episode, check_in: check_in, score: 0.8, rules_severity: "green",
      alert_eligible: true, **overrides)
  end

  context "site not promoted (shadow mode — the enforced default)" do
    it "never creates a flag, however high the score" do
      expect { described_class.call!(risk_score: eligible_risk_score) }.not_to change(Flag, :count)
    end
  end

  context "site promoted" do
    before { create(:risk_model_promotion, site: site, promoted: true) }

    it "creates an ai_watch flag when the score crossed the gate on a green check-in" do
      flag = described_class.call!(risk_score: eligible_risk_score)

      expect(flag).to be_present
      expect(flag.subtype).to eq("ai_watch")
      expect(flag.severity).to eq("yellow")
      expect(flag.sla_deadline_at).to be_nil # UC-23: no SLA pressure
      expect(flag.watch_expires_at).to be_within(1.second).of(5.days.from_now)
      expect(flag.ai_watch_meta["score"]).to eq(0.8)
    end

    it "does not act when the score did not cross the alert gate" do
      expect { described_class.call!(risk_score: eligible_risk_score(alert_eligible: false)) }
        .not_to change(Flag, :count)
    end

    it "does not act on a non-green rules verdict (a real flag already covers it)" do
      expect { described_class.call!(risk_score: eligible_risk_score(rules_severity: "yellow")) }
        .not_to change(Flag, :count)
    end

    it "does not open a second flag when one is already open for the episode" do
      create(:flag, episode: episode, state: "open")

      expect { described_class.call!(risk_score: eligible_risk_score) }.not_to change(Flag, :count)
    end
  end
end
