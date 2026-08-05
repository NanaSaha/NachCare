module Domain
  module Escalation
    # R2: deterministic, LLM-free, pure Ruby, no network calls, no
    # randomness, no clock reads inside evaluation. `evaluate` is a pure
    # function of (ruleset, context) — everything time-dependent (windows,
    # consecutive-day counts, recent severities) must already be resolved
    # into `context` by ContextBuilder before this runs. Identical inputs
    # must produce identical outputs across 1,000 runs (property-tested).
    class Engine
      EvaluationResult = Struct.new(:severity, :fired_rules, keyword_init: true)
      FiredRule = Struct.new(:id, :key, :severity, :explanation_key, :action_template_ids, :brief_template_id, keyword_init: true)

      SEVERITY_RANK = { "green" => 0, "yellow" => 1, "red" => 2 }.freeze

      def self.evaluate(ruleset:, context:)
        new(ruleset:, context:).evaluate
      end

      def initialize(ruleset:, context:)
        @ruleset = ruleset
        @context = context.deep_stringify_keys.freeze
      end

      def evaluate
        fired = ruleset.rules.filter_map { |rule| fired_rule(rule) if condition_met?(rule["condition"]) }
        EvaluationResult.new(severity: overall_severity(fired), fired_rules: fired)
      end

      private

      attr_reader :ruleset, :context

      def fired_rule(rule)
        FiredRule.new(
          id: rule["id"], key: rule["key"], severity: rule["severity"],
          explanation_key: rule["explanation_key"], action_template_ids: rule["action_template_ids"],
          brief_template_id: rule["brief_template_id"]
        )
      end

      def overall_severity(fired)
        return "green" if fired.empty?

        fired.max_by { |r| SEVERITY_RANK.fetch(r.severity, 0) }.severity
      end

      def condition_met?(condition)
        case condition["type"]
        when "weight_gain_over_days" then weight_change_over_days?(condition, direction: :gain)
        when "weight_loss_over_days" then weight_change_over_days?(condition, direction: :loss)
        when "symptom_toggle" then symptom_toggle?(condition)
        when "symptom_combination" then symptom_combination?(condition)
        when "medication_nonadherence" then medication_nonadherence?
        when "missed_checkin" then missed_checkin?(condition)
        when "missing_weight" then missing_weight?(condition)
        when "red_flag_phrases" then red_flag_phrases?
        when "sustained_severity" then sustained_severity?(condition)
        else
          raise ArgumentError, "unknown condition type #{condition['type'].inspect}"
        end
      end

      def weight_change_over_days?(condition, direction:)
        weights = context["weights_by_date"] || {}
        today = context["weight_kg"]
        return false if today.nil?

        past_date = (Date.parse(context["effective_date"]) - condition["days"].to_i).iso8601
        past = weights[past_date]
        return false if past.nil?

        delta = direction == :gain ? today - past : past - today
        delta >= condition["threshold_kg"]
      end

      def symptom_toggle?(condition)
        symptoms = context["symptoms"] || {}
        symptoms[condition["symptom_key"]] == true
      end

      def symptom_combination?(condition)
        symptoms = context["symptoms"] || {}
        keys = condition["symptom_keys"] || []
        if condition["match"] == "any"
          keys.any? { |k| symptoms[k] == true }
        else
          keys.all? { |k| symptoms[k] == true }
        end
      end

      def medication_nonadherence?
        context["medications_missed_critical"] == true
      end

      def missed_checkin?(condition)
        (context["consecutive_missed_checkin_days"] || 0) >= condition["consecutive_days"]
      end

      def missing_weight?(condition)
        (context["consecutive_missing_weight_checkins"] || 0) >= condition["consecutive_check_ins"]
      end

      def red_flag_phrases?
        note = context["note_text"]
        return false if note.blank?

        phrases = ruleset.red_flag_phrases(context["language"] || "en")
        normalized_note = note.downcase
        phrases.any? { |phrase| normalized_note.include?(phrase.downcase) }
      end

      def sustained_severity?(condition)
        recent = context["recent_severities"] || []
        n = condition["consecutive_evaluations"]
        return false if recent.size < n

        recent.first(n).all? { |s| s == condition["severity"] }
      end
    end
  end
end
