module Domain
  module Ai
    # Section 6 #4: the 4-stage assistant pipeline, order matters.
    # (1) EmergencyDetector (2) CategoryRouter (keyword pre-router + LLM)
    # (3) RAG retrieval + answer generation (4) PostChecker. All four
    # stages' verdicts are returned for the caller to persist on the turn.
    #
    # Raises Gateway::AllProvidersFailed if any stage's underlying call
    # exhausts the provider chain — Tasks::Assistant (the task-method
    # boundary) is responsible for catching that and degrading to
    # routed_to_nurse (ADR-0007), not this class.
    class AssistantPipeline
      Result = Struct.new(:text, :citations, :routed, :emergency_detected, :guardrail_verdicts, :routed_flag_id, :degraded, keyword_init: true)

      def initialize(gateway:)
        @gateway = gateway
      end

      def run(episode:, caregiver:, conversation:, language:, message:)
        # Closes over caregiver/episode/conversation so every guardrail
        # stage's gateway.call! is attributable in the ai_calls log
        # without every Guardrails:: class needing to know about them.
        scoped = ScopedGateway.new(gateway, caregiver:, episode:, conversation:)

        verdicts = {}
        safe_message = Redactor.redact(message)

        emergency = Guardrails::EmergencyDetector.check(text: safe_message, language: language, gateway: scoped)
        verdicts["emergency"] = emergency

        category_result = Guardrails::CategoryRouter.route(text: safe_message, language: language, gateway: scoped)
        verdicts["category"] = category_result
        category = category_result["category"]

        if Guardrails::CategoryRouter.routed_to_nurse?(category)
          return routed_result(episode:, language:, category:, emergency:, verdicts:, severity: emergency ? "red" : "yellow")
        end

        if category == "out_of_scope"
          return routed_result(episode:, language:, category:, emergency:, verdicts:, severity: "red", flag_only_if_emergency: true)
        end

        matches = Retrieval.search(query: safe_message, language: language)
        verdicts["retrieval"] = { "match_count" => matches.size, "titles" => matches.map(&:doc_title) }

        if matches.empty?
          return routed_result(episode:, language:, category: "out_of_scope", emergency:, verdicts:, severity: "red", flag_only_if_emergency: true)
        end

        answer_result = scoped.call!(
          task: :assistant,
          system: build_answer_system_prompt(episode:, language:, matches:),
          messages: [ { role: "user", content: safe_message } ]
        )

        post_check = Guardrails::PostChecker.check(drafted_answer: answer_result.text, gateway: scoped)
        verdicts["post_check"] = post_check

        if post_check["flagged"]
          return routed_result(episode:, language:, category: "medication_or_dosage", emergency:, verdicts:, severity: emergency ? "red" : "yellow")
        end

        flag = emergency ? create_routing_flag(episode:, severity: "red", reason: "emergency") : nil
        Result.new(
          text: answer_result.text, citations: matches.map(&:doc_title).uniq, routed: false,
          emergency_detected: emergency, guardrail_verdicts: verdicts, routed_flag_id: flag&.id
        )
      end

      private

      attr_reader :gateway

      # Forwards #call! to the real gateway with caregiver/episode/
      # conversation always attached, so ai_calls rows from inside the
      # pipeline are attributable without threading those three kwargs
      # through every guardrail class's public API.
      ScopedGateway = Struct.new(:gateway, :caregiver, :episode, :conversation) do
        def call!(**kwargs)
          gateway.call!(**kwargs, caregiver:, episode:, conversation:)
        end
      end

      def routed_result(episode:, language:, category:, emergency:, verdicts:, severity:, flag_only_if_emergency: false)
        flag =
          if flag_only_if_emergency
            emergency ? create_routing_flag(episode:, severity:, reason: "emergency") : nil
          else
            create_routing_flag(episode:, severity:, reason: category)
          end

        Result.new(
          text: RoutedResponses.for(category, language), citations: [], routed: true,
          emergency_detected: emergency, guardrail_verdicts: verdicts, routed_flag_id: flag&.id
        )
      end

      def create_routing_flag(episode:, severity:, reason:)
        flag = Flag.create!(
          episode: episode, severity: severity, subtype: "manual", state: "open", opened_at: Time.current,
          sla_deadline_at: Domain::Flags::Sla.deadline_for(episode: episode, severity: severity, from: Time.current)
        )
        Domain::Audit::Recorder.record!(actor: :ai, action: "assistant.routed_to_nurse", entity: flag, payload: { reason: reason })
        Domain::Flags::Broadcaster.call(flag)
        Domain::Notifications::FallbackChain.start_red_chain!(flag: flag) if severity == "red"
        flag
      end

      def build_answer_system_prompt(episode:, language:, matches:)
        context = matches.map { |m| "[[SOURCE: #{m.doc_title}]]\n#{m.chunk.chunk}" }.join("\n\n")
        care_plan = episode.care_plans.find_by(active: true)
        care_plan_summary = care_plan ? "diet_rules: #{care_plan.diet_rules}" : "no active care plan on file"

        PromptAssembler.assemble(template: "assistant_system", vars: {
          "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(episode.patient),
          "USER_LANGUAGE" => language,
          "RETRIEVED_CONTEXT" => context,
          "CARE_PLAN_CONTEXT" => care_plan_summary
        })
      end
    end
  end
end
