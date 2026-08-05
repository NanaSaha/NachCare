module Domain
  module Ai
    # Loads config/ai_emergency_phrases.yml and config/ai_guardrail_keywords.yml
    # once per process (they're small, static config, same pattern as
    # Domain::Escalation::Ruleset loading the ruleset JSON once).
    module GuardrailConfig
      class << self
        def emergency_phrases(language)
          emergency_phrases_config.fetch(language.to_s, emergency_phrases_config.fetch("en", []))
        end

        def medication_terms(language)
          keywords_config.dig("medication_terms", language.to_s) || keywords_config.dig("medication_terms", "en") || []
        end

        def diagnosis_terms(language)
          keywords_config.dig("diagnosis_terms", language.to_s) || keywords_config.dig("diagnosis_terms", "en") || []
        end

        def injection_phrases(language)
          keywords_config.dig("injection_phrases", language.to_s) || keywords_config.dig("injection_phrases", "en") || []
        end

        # Any medication/diagnosis/injection keyword across all configured
        # languages — used by the deterministic pre-router, which should
        # short-circuit regardless of the caregiver's declared UI language
        # (a caregiver might type in a different language than their
        # profile setting).
        def all_medication_terms
          keywords_config.fetch("medication_terms", {}).values.flatten
        end

        def all_diagnosis_terms
          keywords_config.fetch("diagnosis_terms", {}).values.flatten
        end

        def reset_cache!
          @emergency_phrases_config = nil
          @keywords_config = nil
        end

        private

        def emergency_phrases_config
          @emergency_phrases_config ||= YAML.load_file(Rails.root.join("config/ai_emergency_phrases.yml"))
        end

        def keywords_config
          @keywords_config ||= YAML.load_file(Rails.root.join("config/ai_guardrail_keywords.yml"))
        end
      end
    end
  end
end
