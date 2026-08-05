require "rails_helper"

RSpec.describe FlagPolicy do
  let(:site_a) { create(:site) }
  let(:site_b) { create(:site) }
  let(:patient_a) { create(:patient, site: site_a) }
  let(:episode_a) { create(:episode, patient: patient_a) }
  let(:flag_a) { create(:flag, episode: episode_a) }

  describe "show?/index?" do
    it "any staff at the same site can view" do
      %w[ward_nurse nurse physician site_admin analyst].each do |role|
        user = create(:user, role: role, site: site_a)
        expect(described_class.new(user, flag_a).show?).to be(true), "expected #{role} to view"
      end
    end

    it "staff at another site cannot view" do
      user = create(:user, role: "nurse", site: site_b)
      expect(described_class.new(user, flag_a).show?).to be false
    end
  end

  describe "create? (manual flags, FR-N9)" do
    it "managing roles at the same site can create" do
      %w[ward_nurse nurse physician site_admin].each do |role|
        user = create(:user, role: role, site: site_a)
        new_flag = build(:flag, episode: episode_a)
        expect(described_class.new(user, new_flag).create?).to be(true), "expected #{role} to create"
      end
    end

    it "analyst cannot create a manual flag" do
      user = create(:user, role: "analyst", site: site_a)
      new_flag = build(:flag, episode: episode_a)
      expect(described_class.new(user, new_flag).create?).to be false
    end
  end

  describe "update? (state transitions / interventions)" do
    it "nurse, physician, site_admin, sysadmin can update" do
      %w[nurse physician site_admin sysadmin].each do |role|
        user = create(:user, role: role, site: site_a)
        expect(described_class.new(user, flag_a).update?).to be(true), "expected #{role} to update"
      end
    end

    it "ward_nurse cannot update (discharge-side only, ADR-0003)" do
      user = create(:user, role: "ward_nurse", site: site_a)
      expect(described_class.new(user, flag_a).update?).to be false
    end
  end

  describe "Scope" do
    it "scopes to the user's own site via episode -> patient" do
      other_flag = create(:flag, episode: create(:episode, patient: create(:patient, site: site_b)))
      user = create(:user, role: "nurse", site: site_a)

      resolved = described_class::Scope.new(user, Flag).resolve

      expect(resolved).to include(flag_a)
      expect(resolved).not_to include(other_flag)
    end
  end
end
