module Domain
  module Ai
    # Section 6 #2: "Prompt assembly only from config/prompts/*.md
    # templates + structured context." Never builds a prompt from
    # free-form Ruby string interpolation elsewhere — every task's system
    # prompt comes from exactly one of these files, with {{VAR}} tokens
    # substituted. Every substituted value is redacted first (R5) — even
    # values that look structural (e.g. a trend summary) might embed
    # caregiver-authored free text upstream.
    class PromptAssembler
      TEMPLATE_DIR = Rails.root.join("config/prompts")

      def self.assemble(template:, vars: {})
        new.assemble(template:, vars:)
      end

      def assemble(template:, vars: {})
        raw = File.read(TEMPLATE_DIR.join("#{template}.md"))
        vars.reduce(raw) do |text, (key, value)|
          text.gsub("{{#{key}}}", Redactor.redact(value.to_s))
        end
      end
    end
  end
end
