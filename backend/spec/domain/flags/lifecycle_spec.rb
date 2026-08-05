require "rails_helper"

RSpec.describe Domain::Flags::Lifecycle do
  let(:site) { create(:site, sla_red_minutes: 30, sla_yellow_minutes: 240) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }

  def evaluation(severity, created_at: Time.current)
    create(:evaluation, episode: episode, severity: severity, created_at: created_at)
  end

  describe "green evaluations" do
    it "does not create a flag" do
      expect { described_class.record_evaluation!(evaluation: evaluation("green")) }
        .not_to change(Flag, :count)
    end
  end

  describe "no existing open flag" do
    it "creates a new flag with the evaluation's severity and an SLA deadline" do
      eval1 = evaluation("yellow")

      flag = described_class.record_evaluation!(evaluation: eval1)

      expect(flag).to be_persisted
      expect(flag.severity).to eq("yellow")
      expect(flag.state).to eq("open")
      expect(flag.subtype).to eq("clinical")
      expect(flag.evaluation_refs).to eq([ eval1.id ])
      expect(flag.sla_deadline_at).to eq(eval1.created_at + 240.minutes)
    end
  end

  describe "an existing open flag" do
    it "appends the evaluation rather than opening a second flag" do
      eval1 = evaluation("yellow")
      flag1 = described_class.record_evaluation!(evaluation: eval1)

      eval2 = evaluation("yellow")
      flag2 = described_class.record_evaluation!(evaluation: eval2)

      expect(flag2.id).to eq(flag1.id)
      expect(Flag.count).to eq(1)
      expect(flag2.reload.evaluation_refs).to contain_exactly(eval1.id, eval2.id)
    end

    it "escalates severity and recomputes the SLA deadline when a worse evaluation comes in" do
      eval1 = evaluation("yellow", created_at: Time.zone.parse("2026-08-03 10:00:00"))
      described_class.record_evaluation!(evaluation: eval1)

      eval2 = evaluation("red", created_at: Time.zone.parse("2026-08-03 11:00:00"))
      flag = described_class.record_evaluation!(evaluation: eval2)

      expect(flag.severity).to eq("red")
      expect(flag.sla_deadline_at).to eq(eval2.created_at + 30.minutes)
    end

    it "does not downgrade severity or reset the deadline on a milder evaluation" do
      eval1 = evaluation("red", created_at: Time.zone.parse("2026-08-03 10:00:00"))
      flag1 = described_class.record_evaluation!(evaluation: eval1)
      original_deadline = flag1.sla_deadline_at

      eval2 = evaluation("yellow", created_at: Time.zone.parse("2026-08-03 12:00:00"))
      flag2 = described_class.record_evaluation!(evaluation: eval2)

      expect(flag2.severity).to eq("red")
      expect(flag2.sla_deadline_at).to eq(original_deadline)
    end

    it "does not attach to a resolved flag — opens a new one instead" do
      eval1 = evaluation("yellow")
      flag1 = described_class.record_evaluation!(evaluation: eval1)
      flag1.update!(state: "resolved")

      eval2 = evaluation("yellow")
      flag2 = described_class.record_evaluation!(evaluation: eval2)

      expect(flag2.id).not_to eq(flag1.id)
      expect(Flag.count).to eq(2)
    end
  end

  # UC-23 Alternate A1
  describe "an open AI WATCH flag, when rules fire for real" do
    let!(:watch_flag) do
      create(:flag, episode: episode, subtype: "ai_watch", severity: "yellow", state: "open",
        sla_deadline_at: nil, watch_expires_at: 5.days.from_now,
        ai_watch_meta: { "risk_score_id" => 999, "score" => 0.7, "components" => { "weight_velocity" => 1.0 } })
    end

    it "escalates the watch in place into a standard clinical flag, preserving its history" do
      eval1 = evaluation("yellow", created_at: Time.zone.parse("2026-08-03 10:00:00"))

      flag = described_class.record_evaluation!(evaluation: eval1)

      expect(flag.id).to eq(watch_flag.id)
      expect(Flag.count).to eq(1)
      expect(flag.subtype).to eq("clinical")
      expect(flag.severity).to eq("yellow")
      expect(flag.watch_expires_at).to be_nil
      expect(flag.sla_deadline_at).to eq(eval1.created_at + 240.minutes)
      expect(flag.ai_watch_meta["risk_score_id"]).to eq(999) # history preserved
      expect(flag.ai_watch_meta["escalated_to_subtype"]).to eq("clinical")
    end

    it "escalates to red and starts the RED chain when rules fire red" do
      eval1 = evaluation("red", created_at: Time.zone.parse("2026-08-03 10:00:00"))

      expect(Domain::Notifications::FallbackChain).to receive(:start_red_chain!).with(flag: an_instance_of(Flag))

      flag = described_class.record_evaluation!(evaluation: eval1)

      expect(flag.severity).to eq("red")
      expect(flag.subtype).to eq("clinical")
    end

    it "tags the watch's triggering risk_score with the eventual rules outcome" do
      risk_score = create(:risk_score, episode: episode, outcome: nil)
      watch_flag.update!(ai_watch_meta: watch_flag.ai_watch_meta.merge("risk_score_id" => risk_score.id))

      eval1 = evaluation("yellow")
      described_class.record_evaluation!(evaluation: eval1)

      expect(risk_score.reload.outcome).to eq("flag_yellow")
    end
  end
end
