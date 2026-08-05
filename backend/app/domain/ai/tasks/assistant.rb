module Domain
  module Ai
    module Tasks
      # Gateway#assistant_reply task boundary: runs AssistantPipeline and,
      # if the provider chain is exhausted at any stage
      # (Gateway::AllProvidersFailed), degrades per Section 6 #1:
      # "assistant: return routed_to_nurse response object + create
      # cockpit task" — fail-closed, matching R3's "if any layer is
      # uncertain, route."
      class Assistant
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          AssistantPipeline.new(gateway: gateway).run(
            episode: ctx.fetch(:episode), caregiver: ctx.fetch(:caregiver), conversation: ctx.fetch(:conversation),
            language: ctx.fetch(:language), message: ctx.fetch(:message)
          )
        rescue Gateway::AllProvidersFailed => e
          Rails.logger.warn("[Domain::Ai::Tasks::Assistant] degraded to routed_to_nurse: #{e.message}")
          degrade(ctx)
        end

        private

        attr_reader :gateway

        def degrade(ctx)
          episode = ctx.fetch(:episode)
          flag = Flag.create!(
            episode: episode, severity: "yellow", subtype: "manual", state: "open", opened_at: Time.current,
            sla_deadline_at: Domain::Flags::Sla.deadline_for(episode: episode, severity: "yellow", from: Time.current)
          )
          Domain::Audit::Recorder.record!(actor: :ai, action: "assistant.degraded_routed_to_nurse", entity: flag, payload: {})
          Domain::Flags::Broadcaster.call(flag)

          AssistantPipeline::Result.new(
            text: RoutedResponses.for("out_of_scope", ctx.fetch(:language)), citations: [], routed: true,
            emergency_detected: false, guardrail_verdicts: { "degraded" => true }, routed_flag_id: flag.id, degraded: true
          )
        end
      end
    end
  end
end
