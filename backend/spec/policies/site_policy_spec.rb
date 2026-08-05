require "rails_helper"

RSpec.describe SitePolicy do
  let(:site_a) { create(:site) }
  let(:site_b) { create(:site) }
  let(:sysadmin) { create(:user, role: "sysadmin", site: site_a) }
  let(:site_admin_a) { create(:user, role: "site_admin", site: site_a) }
  let(:nurse_a) { create(:user, role: "nurse", site: site_a) }

  subject { described_class.new(user, site_a) }

  context "sysadmin" do
    let(:user) { sysadmin }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
  end

  context "site_admin of the same site" do
    let(:user) { site_admin_a }

    it { is_expected.not_to be_index }
    it { is_expected.to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.to be_update }
  end

  context "site_admin of a different site" do
    let(:user) { create(:user, role: "site_admin", site: site_b) }

    it { is_expected.not_to be_show }
    it { is_expected.not_to be_update }
  end

  context "nurse of the same site" do
    let(:user) { nurse_a }

    it { is_expected.to be_show }
    it { is_expected.not_to be_update }
  end

  describe "Scope" do
    it "returns all sites for sysadmin" do
      site_b # ensure it exists
      resolved = described_class::Scope.new(sysadmin, Site).resolve
      expect(resolved).to include(site_a, site_b)
    end

    it "returns only the user's own site for non-sysadmin" do
      site_b
      resolved = described_class::Scope.new(nurse_a, Site).resolve
      expect(resolved.to_a).to eq([ site_a ])
    end
  end
end
