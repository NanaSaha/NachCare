module Domain
  module Messages
    # M5: now backed by the real T-TRANSLATE pipeline
    # (Domain::Ai::Tasks::Translate) instead of the M4 EN-passthrough
    # stub (docs/OPEN_CLINICAL_ITEMS.md #6). Contract is unchanged: the
    # nurse always reviews body_translated in the "preview" step before
    # send (show-before-send) — swapping the stub for a real LLM call
    # doesn't touch that guarantee. Still returns nil on failure/
    # degradation (Gateway::AllProvidersFailed, or same-language) so the
    # UI falls back to "not yet translated, write it by hand," exactly
    # like the M4 stub did.
    class TranslateAssist
      def self.suggest(body_source:, target_language:, source_language: "en")
        Domain::Ai::Gateway.translate(body_source: body_source, source_language: source_language, target_language: target_language)
      end
    end
  end
end
