module Domain
  module Escalation
    # Immutable wrapper around a parsed ruleset body (whether loaded from
    # config/rulesets/*.json or a `rulesets.body` DB row — same shape
    # either way). Rule = a plain Hash with string keys, matching the JSON
    # verbatim; kept as-is rather than parsed into objects so the engine's
    # inputs stay trivially serializable for the inputs_sha256 hash.
    class Ruleset
      class InvalidRuleset < StandardError; end

      attr_reader :version, :body

      def self.load_from_file(path)
        new(JSON.parse(File.read(path)))
      end

      def initialize(body)
        @body = body.deep_stringify_keys.freeze
        @version = @body.fetch("version") { raise InvalidRuleset, "ruleset body missing 'version'" }
        validate!
      end

      def rules
        @rules ||= body.fetch("rules", []).freeze
      end

      def find_rule(id)
        rules.find { |r| r["id"] == id }
      end

      def red_flag_phrases(language)
        phrases = body.dig("red_flag_phrases", language)
        phrases || body.dig("red_flag_phrases", "en") || []
      end

      private

      def validate!
        raise InvalidRuleset, "ruleset has no rules" if rules.empty?

        rules.each do |rule|
          %w[id key severity condition].each do |field|
            raise InvalidRuleset, "rule #{rule['id'] || '?'} missing '#{field}'" unless rule.key?(field)
          end
          unless %w[green yellow red].include?(rule["severity"])
            raise InvalidRuleset, "rule #{rule['id']} has invalid severity #{rule['severity'].inspect}"
          end
        end
      end
    end
  end
end
