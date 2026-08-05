require "rails_helper"

RSpec.describe Domain::Risk::Promoter do
  let(:site) { create(:site) }
  let(:decider) { create(:user, site: site, role: "physician") }

  it "does not promote when the gates aren't met and no override is given" do
    record = described_class.decide!(site: site, decided_by: decider, override: false)

    expect(record.promoted).to be false
    expect(record.gates_met).to be false
    expect(record.override).to be false
    expect(site.ai_watch_promoted?).to be false
  end

  it "promotes via the dev/demo override when the gates aren't met, and marks it as an override" do
    record = described_class.decide!(site: site, decided_by: decider, override: true)

    expect(record.promoted).to be true
    expect(record.gates_met).to be false
    expect(record.override).to be true
    expect(site.ai_watch_promoted?).to be true
  end

  it "promotes on real gate-passing data without needing an override" do
    5.times do |i|
      ci = create(:check_in, episode: create(:episode, patient: create(:patient, site: site)), effective_date: Date.current - 10 + i)
      create(:risk_score, episode: ci.episode, check_in: ci, alert_eligible: true, outcome: "flag_yellow",
        outcome_evaluated_at: ci.effective_date + 3.days)
    end
    60.times { |i| create(:check_in, episode: create(:episode, patient: create(:patient, site: site)), effective_date: Date.current - i) }

    record = described_class.decide!(site: site, decided_by: decider, override: false)

    expect(record.gates_met).to be true
    expect(record.promoted).to be true
    expect(record.override).to be false
  end

  it "writes an audited RiskModelPromotion row every time a decision is made" do
    expect { described_class.decide!(site: site, decided_by: decider, override: false) }
      .to change(RiskModelPromotion, :count).by(1)
      .and change(AuditEvent, :count).by(1)
  end

  it "always re-computes the gates server-side, never trusting a caller-supplied verdict" do
    expect(Domain::Risk::PromotionGate).to receive(:evaluate).with(site: site).and_call_original

    described_class.decide!(site: site, decided_by: decider, override: false)
  end
end
