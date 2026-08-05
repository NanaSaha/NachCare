require "rails_helper"

RSpec.describe Domain::Risk::CadenceAdvisor do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, site: site, role: "nurse") }

  def add_scores(value, count: 4)
    count.times { |i| create(:risk_score, episode: episode, check_in: create(:check_in, episode: episode, effective_date: Date.current - i), score: value) }
  end

  describe "#refresh!" do
    it "proposes nothing pre-promotion" do
      add_scores(0.05)
      expect(described_class.refresh!(episode)).to be_nil
      expect(CadenceProposal.count).to eq(0)
    end

    context "promoted" do
      before { create(:risk_model_promotion, site: site, promoted: true) }

      it "proposes nothing with insufficient score history" do
        add_scores(0.05, count: 3)
        expect(described_class.refresh!(episode)).to be_nil
      end

      it "proposes a taper for a stable low-risk trend" do
        add_scores(0.05)

        proposal = described_class.refresh!(episode)

        expect(proposal).to be_persisted
        expect(proposal.direction).to eq("taper")
        expect(proposal.status).to eq("pending")
      end

      it "proposes densify for a high/rising-risk trend" do
        add_scores(0.6)

        proposal = described_class.refresh!(episode)

        expect(proposal.direction).to eq("densify")
      end

      it "is idempotent — does not open a second proposal while one is pending" do
        add_scores(0.05)
        first = described_class.refresh!(episode)

        second = described_class.refresh!(episode)

        expect(second.id).to eq(first.id)
        expect(CadenceProposal.count).to eq(1)
      end
    end
  end

  describe "#approve!" do
    it "creates a new versioned care plan with the proposed cadence and marks the proposal approved" do
      create(:care_plan, episode: episode, active: true, version: 1, cadence: { "times_per_week" => 1 })
      proposal = create(:cadence_proposal, episode: episode, direction: "taper", proposed_cadence: { "times_per_week" => 3 })

      care_plan = described_class.new(episode).approve!(proposal, decided_by: nurse)

      expect(care_plan.cadence).to eq({ "times_per_week" => 3 })
      expect(care_plan.version).to eq(2)
      expect(episode.care_plans.find_by(version: 1).active).to be false
      expect(proposal.reload.status).to eq("approved")
      expect(proposal.decided_by).to eq(nurse.id)
    end
  end

  describe "#dismiss!" do
    it "marks the proposal dismissed without touching the care plan" do
      proposal = create(:cadence_proposal, episode: episode)

      expect { described_class.new(episode).dismiss!(proposal, decided_by: nurse) }
        .not_to change(CarePlan, :count)

      expect(proposal.reload.status).to eq("dismissed")
    end
  end
end
