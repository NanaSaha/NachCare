require "rails_helper"

RSpec.describe PatientPolicy do
  let(:site_a) { create(:site) }
  let(:site_b) { create(:site) }
  let(:patient_a) { create(:patient, site: site_a) }

  describe "show?/index?" do
    it "any staff role at the same site can view" do
      %w[ward_nurse nurse physician site_admin analyst].each do |role|
        user = create(:user, role: role, site: site_a)
        expect(described_class.new(user, patient_a).show?).to be(true), "expected #{role} to view"
      end
    end

    it "staff at a different site cannot view" do
      user = create(:user, role: "nurse", site: site_b)
      expect(described_class.new(user, patient_a).show?).to be false
    end

    it "sysadmin can view any site" do
      user = create(:user, role: "sysadmin", site: site_b)
      expect(described_class.new(user, patient_a).show?).to be true
    end
  end

  describe "create?/update?" do
    it "ward_nurse, nurse, physician, site_admin can enroll at their own site" do
      %w[ward_nurse nurse physician site_admin].each do |role|
        user = create(:user, role: role, site: site_a)
        expect(described_class.new(user, patient_a).create?).to be(true), "expected #{role} to enroll"
      end
    end

    it "analyst cannot enroll" do
      user = create(:user, role: "analyst", site: site_a)
      expect(described_class.new(user, patient_a).create?).to be false
    end

    it "staff cannot enroll at another site" do
      user = create(:user, role: "nurse", site: site_b)
      expect(described_class.new(user, patient_a).create?).to be false
    end
  end

  describe "Scope" do
    it "scopes to the user's own site" do
      other_patient = create(:patient, site: site_b)
      user = create(:user, role: "nurse", site: site_a)
      resolved = described_class::Scope.new(user, Patient).resolve
      expect(resolved).to include(patient_a)
      expect(resolved).not_to include(other_patient)
    end
  end
end
