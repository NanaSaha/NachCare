require "rails_helper"

RSpec.describe Domain::Escalation::Ruleset do
  let(:seed_path) { Rails.root.join("config/rulesets/ruleset_v0_1.json") }

  describe ".load_from_file" do
    it "loads the seed ruleset with all 11 rules" do
      ruleset = described_class.load_from_file(seed_path)

      expect(ruleset.version).to eq("0.1.0-placeholder")
      expect(ruleset.rules.map { |r| r["id"] }).to eq((1..11).map { |n| "R-#{n}" })
    end

    it "every rule is marked placeholder_clinical (R1: no invented clinical content)" do
      ruleset = described_class.load_from_file(seed_path)

      expect(ruleset.rules).to all(include("placeholder_clinical" => true))
    end
  end

  describe "#find_rule" do
    it "finds a rule by id" do
      ruleset = described_class.load_from_file(seed_path)
      expect(ruleset.find_rule("R-4")["key"]).to eq("breathless_at_rest")
    end

    it "returns nil for an unknown id" do
      ruleset = described_class.load_from_file(seed_path)
      expect(ruleset.find_rule("R-999")).to be_nil
    end
  end

  describe "#red_flag_phrases" do
    it "returns the phrases for the requested language" do
      ruleset = described_class.load_from_file(seed_path)
      expect(ruleset.red_flag_phrases("de").size).to eq(15)
    end

    it "falls back to English for an unknown language" do
      ruleset = described_class.load_from_file(seed_path)
      expect(ruleset.red_flag_phrases("tr")).to eq(ruleset.red_flag_phrases("en"))
    end
  end

  describe "validation" do
    it "rejects a body with no version" do
      expect { described_class.new({ "rules" => [] }) }
        .to raise_error(Domain::Escalation::Ruleset::InvalidRuleset, /version/)
    end

    it "rejects a body with no rules" do
      expect { described_class.new({ "version" => "x", "rules" => [] }) }
        .to raise_error(Domain::Escalation::Ruleset::InvalidRuleset, /no rules/)
    end

    it "rejects a rule missing a required field" do
      body = { "version" => "x", "rules" => [ { "id" => "R-1", "key" => "k", "severity" => "red" } ] }
      expect { described_class.new(body) }
        .to raise_error(Domain::Escalation::Ruleset::InvalidRuleset, /condition/)
    end

    it "rejects a rule with an invalid severity" do
      body = { "version" => "x", "rules" => [ { "id" => "R-1", "key" => "k", "severity" => "purple", "condition" => {} } ] }
      expect { described_class.new(body) }
        .to raise_error(Domain::Escalation::Ruleset::InvalidRuleset, /severity/)
    end
  end
end
