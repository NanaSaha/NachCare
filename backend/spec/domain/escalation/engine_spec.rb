require "rails_helper"

RSpec.describe Domain::Escalation::Engine do
  let(:ruleset) { Domain::Escalation::Ruleset.load_from_file(Rails.root.join("config/rulesets/ruleset_v0_1.json")) }

  def base_context
    {
      effective_date: "2026-08-03",
      weight_kg: 70.0,
      weights_by_date: {},
      symptoms: {},
      medications_missed_critical: false,
      consecutive_missed_checkin_days: 0,
      consecutive_missing_weight_checkins: 0,
      note_text: nil,
      language: "en",
      recent_severities: []
    }
  end

  describe "no rules fire" do
    it "is green with no fired rules" do
      result = described_class.evaluate(ruleset: ruleset, context: base_context)
      expect(result.severity).to eq("green")
      expect(result.fired_rules).to be_empty
    end
  end

  describe "R-1 rapid_weight_gain (red)" do
    it "fires when the gain over the window meets the threshold" do
      context = base_context.merge(
        weight_kg: 999 + 70.0,
        weights_by_date: { "2026-08-01" => 70.0 }
      )
      result = described_class.evaluate(ruleset: ruleset, context: context)

      expect(result.severity).to eq("red")
      expect(result.fired_rules.map(&:id)).to include("R-1")
    end

    it "does not fire below the threshold" do
      context = base_context.merge(
        weight_kg: 70.5,
        weights_by_date: { "2026-08-01" => 70.0 }
      )
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).not_to include("R-1")
    end

    it "does not fire when there is no historical weight to compare against" do
      context = base_context.merge(weight_kg: 200.0, weights_by_date: {})
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).not_to include("R-1")
    end
  end

  describe "R-3 weight_loss (yellow)" do
    it "fires on a large loss, not gain" do
      context = base_context.merge(
        effective_date: "2026-08-08",
        weight_kg: 70.0,
        weights_by_date: { "2026-08-01" => 70.0 + 999 }
      )
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).to include("R-3")
    end
  end

  describe "R-4 breathless_at_rest (red, single symptom toggle)" do
    it "fires when the symptom is true" do
      context = base_context.merge(symptoms: { "breathless_at_rest" => true })
      result = described_class.evaluate(ruleset: ruleset, context: context)

      expect(result.severity).to eq("red")
      expect(result.fired_rules.map(&:id)).to include("R-4")
    end

    it "does not fire when false or absent" do
      result = described_class.evaluate(ruleset: ruleset, context: base_context)
      expect(result.fired_rules.map(&:id)).not_to include("R-4")
    end
  end

  describe "R-6 symptom_combination (red, requires ALL listed symptoms)" do
    it "does not fire with only one of the two symptoms" do
      context = base_context.merge(symptoms: { "swelling_increased" => true })
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).not_to include("R-6")
    end

    it "fires when both symptoms are present" do
      context = base_context.merge(symptoms: { "swelling_increased" => true, "fatigue_increased" => true })
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).to include("R-6")
    end
  end

  describe "R-7 medication_nonadherence (yellow)" do
    it "fires when a critical medication was missed" do
      context = base_context.merge(medications_missed_critical: true)
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).to include("R-7")
      expect(result.severity).to eq("yellow")
    end
  end

  describe "R-8 missed_checkin (yellow)" do
    it "fires once the consecutive-missed-day threshold is met" do
      context = base_context.merge(consecutive_missed_checkin_days: 1)
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).to include("R-8")
    end
  end

  describe "R-9 missing_weight (yellow)" do
    it "fires at the configured consecutive count" do
      context = base_context.merge(consecutive_missing_weight_checkins: 3)
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).to include("R-9")
    end

    it "does not fire below the count" do
      context = base_context.merge(consecutive_missing_weight_checkins: 2)
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).not_to include("R-9")
    end
  end

  describe "R-10 red_flag_phrases (red, free-text matching)" do
    it "fires when the note contains a seeded placeholder phrase, case-insensitively" do
      phrase = ruleset.red_flag_phrases("en").first
      context = base_context.merge(note_text: "Some text with #{phrase.upcase} embedded in it")
      result = described_class.evaluate(ruleset: ruleset, context: context)

      expect(result.severity).to eq("red")
      expect(result.fired_rules.map(&:id)).to include("R-10")
    end

    it "does not fire on unrelated text" do
      context = base_context.merge(note_text: "Feeling fine today, ate breakfast.")
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).not_to include("R-10")
    end

    it "does not fire when there is no note" do
      result = described_class.evaluate(ruleset: ruleset, context: base_context)
      expect(result.fired_rules.map(&:id)).not_to include("R-10")
    end
  end

  describe "R-11 sustained_yellow_escalation (red, meta-rule over recent evaluations)" do
    it "fires after enough consecutive yellow evaluations" do
      context = base_context.merge(recent_severities: %w[yellow yellow yellow green])
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).to include("R-11")
    end

    it "does not fire if the streak is broken" do
      context = base_context.merge(recent_severities: %w[yellow green yellow])
      result = described_class.evaluate(ruleset: ruleset, context: context)
      expect(result.fired_rules.map(&:id)).not_to include("R-11")
    end
  end

  describe "overall severity is the max across all fired rules" do
    it "is red when both a yellow and a red rule fire" do
      context = base_context.merge(
        medications_missed_critical: true, # R-7 yellow
        symptoms: { "breathless_at_rest" => true } # R-4 red
      )
      result = described_class.evaluate(ruleset: ruleset, context: context)

      expect(result.severity).to eq("red")
      expect(result.fired_rules.map(&:id)).to contain_exactly("R-4", "R-7")
    end
  end

  describe "unknown condition type" do
    it "raises rather than silently evaluating to false" do
      bogus_ruleset = Domain::Escalation::Ruleset.new(
        "version" => "x",
        "rules" => [ { "id" => "R-X", "key" => "x", "severity" => "red", "condition" => { "type" => "not_a_real_type" } } ]
      )
      expect { described_class.evaluate(ruleset: bogus_ruleset, context: base_context) }
        .to raise_error(ArgumentError, /unknown condition type/)
    end
  end

  describe "determinism (R2, M2 gate)" do
    it "produces identical output for identical input across 1,000 runs" do
      context = base_context.merge(
        weight_kg: 999 + 70.0,
        weights_by_date: { "2026-08-01" => 70.0 },
        symptoms: { "breathless_at_rest" => true, "swelling_increased" => true, "fatigue_increased" => true },
        medications_missed_critical: true,
        consecutive_missed_checkin_days: 1,
        consecutive_missing_weight_checkins: 3,
        note_text: "contains #{ruleset.red_flag_phrases('en').first}",
        recent_severities: %w[yellow yellow yellow]
      )

      results = Array.new(1000) { described_class.evaluate(ruleset: ruleset, context: context) }

      severities = results.map(&:severity).uniq
      fired_id_sets = results.map { |r| r.fired_rules.map(&:id).sort }.uniq

      expect(severities).to eq([ "red" ])
      expect(fired_id_sets.size).to eq(1)
    end

    it "does not mutate the context or ruleset between runs" do
      context = base_context.merge(symptoms: { "breathless_at_rest" => true })
      frozen_context = context.deep_dup.freeze

      10.times { described_class.evaluate(ruleset: ruleset, context: context) }

      expect(context).to eq(frozen_context)
    end
  end
end
