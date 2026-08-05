require "rails_helper"

RSpec.describe UserPolicy do
  let(:site_a) { create(:site) }
  let(:site_b) { create(:site) }
  let(:sysadmin) { create(:user, role: "sysadmin", site: site_a) }
  let(:site_admin_a) { create(:user, role: "site_admin", site: site_a) }
  let(:nurse_a) { create(:user, role: "nurse", site: site_a) }
  let(:target_nurse_a) { create(:user, role: "nurse", site: site_a) }
  let(:target_sysadmin) { create(:user, role: "sysadmin", site: site_a) }

  describe "create? / update?" do
    it "sysadmin can create/update anyone, any role, any site" do
      policy = described_class.new(sysadmin, build(:user, role: "site_admin", site: site_b))
      expect(policy.create?).to be true
    end

    it "site_admin can create a nurse at their own site" do
      policy = described_class.new(site_admin_a, build(:user, role: "nurse", site: site_a))
      expect(policy.create?).to be true
    end

    it "site_admin cannot create a sysadmin" do
      policy = described_class.new(site_admin_a, build(:user, role: "sysadmin", site: site_a))
      expect(policy.create?).to be false
    end

    it "site_admin cannot create staff at another site" do
      policy = described_class.new(site_admin_a, build(:user, role: "nurse", site: site_b))
      expect(policy.create?).to be false
    end

    it "a nurse cannot create other staff" do
      policy = described_class.new(nurse_a, build(:user, role: "nurse", site: site_a))
      expect(policy.create?).to be false
    end

    it "any user can update their own profile" do
      policy = described_class.new(nurse_a, nurse_a)
      expect(policy.update?).to be true
    end

    it "a nurse cannot update another user's profile" do
      policy = described_class.new(nurse_a, target_nurse_a)
      expect(policy.update?).to be false
    end
  end

  describe "show?" do
    it "site_admin can view staff at their own site" do
      expect(described_class.new(site_admin_a, target_nurse_a).show?).to be true
    end

    it "site_admin cannot view staff at another site" do
      other_site_user = create(:user, role: "nurse", site: site_b)
      expect(described_class.new(site_admin_a, other_site_user).show?).to be false
    end
  end

  describe "Scope" do
    it "sysadmin sees everyone" do
      target_nurse_a
      resolved = described_class::Scope.new(sysadmin, User).resolve
      expect(resolved).to include(target_nurse_a, sysadmin)
    end

    it "site_admin sees only their own site" do
      target_nurse_a
      other_site_user = create(:user, role: "nurse", site: site_b)
      resolved = described_class::Scope.new(site_admin_a, User).resolve
      expect(resolved).to include(target_nurse_a)
      expect(resolved).not_to include(other_site_user)
    end
  end
end
