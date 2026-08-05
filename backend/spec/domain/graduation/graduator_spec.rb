require "rails_helper"

RSpec.describe Domain::Graduation::Graduator do
  describe "#graduate!" do
    it "raises NotEligible before day 90" do
      episode = create(:episode, start_date: 10.days.ago.to_date)
      user = create(:user)

      expect { described_class.graduate!(episode: episode, actor: user) }
        .to raise_error(described_class::NotEligible)
    end

    it "raises AlreadyGraduated for an already-graduated episode" do
      episode = create(:episode, start_date: 90.days.ago.to_date, status: "graduated")
      user = create(:user)

      expect { described_class.graduate!(episode: episode, actor: user) }
        .to raise_error(described_class::AlreadyGraduated)
    end

    it "transitions status, snapshots a report into milestones, and records an audit event" do
      episode = create(:episode, start_date: 90.days.ago.to_date)
      create(:caregiver, episode: episode, language: "en")
      user = create(:user)

      result = described_class.graduate!(episode: episode, actor: user)

      expect(result.status).to eq("graduated")
      expect(result.milestones["graduated_at"]).to be_present
      expect(result.milestones["graduated_by"]).to eq(user.id.to_s)
      expect(result.milestones).to have_key("graduation_report")

      event = AuditEvent.order(:created_at).last
      expect(event.action).to eq("episode.graduated")
      expect(event.entity_type).to eq("episode")
      expect(event.entity_ref).to eq(episode.id.to_s)
    end
  end
end
