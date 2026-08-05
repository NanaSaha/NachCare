module Domain
  module Ai
    # R5: strips phone numbers and email addresses out of any free text
    # before it's placed into an LLM prompt/context. Deliberately
    # conservative (over-redact rather than under-redact) — false
    # positives just mean a stray digit run gets masked, false negatives
    # mean PHI reaches a third-party API.
    class Redactor
      EMAIL_RE = /[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i

      # Phone-ish: 6+ digits, optionally grouped with spaces/dashes/dots/
      # parens, optionally with a leading +. Matches "+49 171 2345678",
      # "0171-2345678", "(030) 123456", etc.
      PHONE_RE = /(?<![\w])(\+?\d[\d\s\-.()]{5,}\d)(?![\w])/

      def self.redact(text)
        new.redact(text)
      end

      def redact(text)
        return text if text.blank?

        text.gsub(EMAIL_RE, "[REDACTED_EMAIL]").gsub(PHONE_RE, "[REDACTED_PHONE]")
      end
    end
  end
end
