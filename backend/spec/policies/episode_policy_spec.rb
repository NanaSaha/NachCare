require "rails_helper"

RSpec.describe EpisodePolicy do
  let(:site_a) { create(:site) }
  let(:site_b) { create(:site) }
  let(:patient_a) { create(:patient, site: site_a) }
  let(:episode_a) { create(:episode, patient: patient_a) }

  it "staff at the patient's site can view, staff at another site cannot" do
    same_site_user = create(:user, role: "nurse", site: site_a)
    other_site_user = create(:user, role: "nurse", site: site_b)

    expect(described_class.new(same_site_user, episode_a).show?).to be true
    expect(described_class.new(other_site_user, episode_a).show?).to be false
  end

  it "enrolling roles can create/update, analyst cannot" do
    nurse = create(:user, role: "nurse", site: site_a)
    analyst = create(:user, role: "analyst", site: site_a)

    expect(described_class.new(nurse, episode_a).create?).to be true
    expect(described_class.new(analyst, episode_a).create?).to be false
  end

  it "graduate? excludes ward_nurse and other-site staff, allows nurse/physician at the same site" do
    ward_nurse = create(:user, role: "ward_nurse", site: site_a)
    nurse = create(:user, role: "nurse", site: site_a)
    other_site_nurse = create(:user, role: "nurse", site: site_b)
    analyst = create(:user, role: "analyst", site: site_a)

    expect(described_class.new(ward_nurse, episode_a).graduate?).to be false
    expect(described_class.new(nurse, episode_a).graduate?).to be true
    expect(described_class.new(other_site_nurse, episode_a).graduate?).to be false
    expect(described_class.new(analyst, episode_a).graduate?).to be false
  end

  describe "Scope" do
    it "resolves via the patient's site, since Episode has no site_ref of its own" do
      other_episode = create(:episode, patient: create(:patient, site: site_b))
      user = create(:user, role: "nurse", site: site_a)

      resolved = described_class::Scope.new(user, Episode).resolve

      expect(resolved).to include(episode_a)
      expect(resolved).not_to include(other_episode)
    end
  end
end
