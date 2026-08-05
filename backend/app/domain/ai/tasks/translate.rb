module Domain
  module Ai
    module Tasks
      # T-TRANSLATE, replacing the M4 Domain::Messages::TranslateAssist
      # stub (docs/OPEN_CLINICAL_ITEMS.md #6). Same contract the stub
      # already established: nil on failure so the UI falls back to
      # "not yet translated, write it by hand" — the nurse always reviews
      # body_translated before send either way, so this swap doesn't
      # change that show-before-send guarantee. ctx: {body_source:,
      # target_language:, source_language:}
      class Translate
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          target = ctx.fetch(:target_language)
          return ctx.fetch(:body_source) if target.to_s == ctx.fetch(:source_language, "en").to_s

          system = PromptAssembler.assemble(template: "translate", vars: {
            "SOURCE_LANGUAGE" => ctx.fetch(:source_language, "en"),
            "TARGET_LANGUAGE" => target,
            "SOURCE_TEXT" => ctx.fetch(:body_source)
          })

          result = gateway.call!(task: :translate, system: system, messages: [ { role: "user", content: ctx.fetch(:body_source) } ])
          result.text
        rescue Gateway::AllProvidersFailed
          nil
        end

        private

        attr_reader :gateway
      end
    end
  end
end
