require "rails_helper"

RSpec.describe Ruleset do
  it "enforces at most one active ruleset at the DB level" do
    create(:ruleset, status: "active")

    expect { create(:ruleset, status: "active") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows multiple draft/shadow/retired rulesets" do
    create(:ruleset, status: "draft")
    expect { create(:ruleset, status: "draft") }.not_to raise_error
  end

  describe ".active / .shadow" do
    it "finds the active ruleset" do
      active = create(:ruleset, status: "active")
      create(:ruleset, status: "draft")

      expect(described_class.active).to eq(active)
    end

    it "finds all shadow rulesets" do
      shadow = create(:ruleset, status: "shadow")
      create(:ruleset, status: "draft")

      expect(described_class.shadow).to contain_exactly(shadow)
    end
  end

  describe "#to_domain" do
    it "wraps the body in a Domain::Escalation::Ruleset" do
      record = create(:ruleset, body: {
        "version" => "test-1",
        "rules" => [ { "id" => "R-1", "key" => "k", "severity" => "red", "condition" => { "type" => "symptom_toggle", "symptom_key" => "x" } } ]
      })

      domain_ruleset = record.to_domain
      expect(domain_ruleset).to be_a(Domain::Escalation::Ruleset)
      expect(domain_ruleset.version).to eq("test-1")
    end
  end
end
