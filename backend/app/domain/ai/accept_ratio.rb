module Domain
  module Ai
    # Section 8/M5: "copilot T-TRIAGE ... edit-tracking into
    # interventions.ai_accept_ratio." A lightweight, deterministic
    # word-overlap (Jaccard) similarity between the AI draft and what the
    # nurse actually saved — 1.0 means unedited, 0.0 means unrelated.
    # Not a clinical judgment, just a text-diff metric — pure engineering.
    module AcceptRatio
      def self.compute(ai_text, final_text)
        return nil if ai_text.blank? || final_text.blank?

        ai_words = ai_text.downcase.scan(/\w+/).to_set
        final_words = final_text.downcase.scan(/\w+/).to_set
        return 1.0 if ai_words.empty? && final_words.empty?

        union = ai_words | final_words
        return 0.0 if union.empty?

        (ai_words & final_words).size.to_f / union.size
      end
    end
  end
end
