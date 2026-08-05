module Domain
  module Escalation
    # Orchestrates one check-in (or the R-8 nightly scan, check_in: nil)
    # through ContextBuilder -> Engine -> Evaluation persistence -> Flag
    # lifecycle. Also runs any `shadow` ruleset alongside `active` (FR-E*
    # shadow mode): shadow evaluations are persisted for comparison but
    # never feed the flag lifecycle.
    class Processor
      Result = Struct.new(:evaluation, :flag, :context, keyword_init: true)

      def self.process!(episode:, check_in: nil, as_of: Time.current)
        new(episode:, check_in:, as_of:).process!
      end

      def initialize(episode:, check_in:, as_of:)
        @episode = episode
        @check_in = check_in
        @as_of = as_of
      end

      def process!
        context = ContextBuilder.build(episode: episode, check_in: check_in, as_of: as_of)

        process_shadow_rulesets(context)

        active = ::Ruleset.active
        return Result.new(evaluation: nil, flag: nil, context: context) unless active

        result = Engine.evaluate(ruleset: active.to_domain, context: context)
        evaluation = persist_evaluation(active, context, result)
        flag = Domain::Flags::Lifecycle.record_evaluation!(evaluation: evaluation)

        Result.new(evaluation: evaluation, flag: flag, context: context)
      end

      private

      attr_reader :episode, :check_in, :as_of

      def process_shadow_rulesets(context)
        ::Ruleset.shadow.find_each do |shadow_ruleset|
          result = Engine.evaluate(ruleset: shadow_ruleset.to_domain, context: context)
          persist_evaluation(shadow_ruleset, context, result)
        end
      end

      def persist_evaluation(ruleset_record, context, result)
        ::Evaluation.create!(
          check_in: check_in,
          episode: episode,
          ruleset_version: ruleset_record.version,
          inputs_sha256: Digest::SHA256.hexdigest(JSON.generate(canonicalize(context))),
          severity: result.severity,
          fired_rules: result.fired_rules.map { |r| r.to_h.stringify_keys },
          created_at: as_of
        )
      end

      def canonicalize(obj)
        case obj
        when Hash
          obj.map { |k, v| [ k.to_s, canonicalize(v) ] }.sort_by(&:first).to_h
        when Array
          obj.map { |v| canonicalize(v) }
        else
          obj
        end
      end
    end
  end
end
