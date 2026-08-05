module Domain
  module Ai
    module Guardrails
      # Section 6 #4: "a deterministic keyword pre-router for obvious
      # medication terms (multilingual list in config) that short-circuits
      # without an LLM call." Runs before CategoryRouter's LLM call — if
      # this matches, no provider call happens at all for classification,
      # so it works even if the AI gateway is fully down (R3 layered
      # defense: "hardcoded category router").
      #
      # Checks keywords across *all* configured languages, not just the
      # caregiver's declared language, since a caregiver may type in a
      # different language than their profile setting.
      module KeywordPreRouter
        def self.route(text)
          normalized = text.to_s.downcase
          return "medication_or_dosage" if Domain::Ai::GuardrailConfig.all_medication_terms.any? { |k| normalized.include?(k.downcase) }
          return "diagnosis_or_prognosis" if Domain::Ai::GuardrailConfig.all_diagnosis_terms.any? { |k| normalized.include?(k.downcase) }

          nil
        end
      end
    end
  end
end
