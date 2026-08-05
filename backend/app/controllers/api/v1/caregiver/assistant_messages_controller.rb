module Api
  module V1
    module Caregiver
      # Assistant chat (Section 8/M5). One ongoing AssistantConversation
      # per caregiver+episode; #create appends a caregiver turn, runs the
      # full 4-stage pipeline via Domain::Ai::Gateway#assistant_reply, and
      # appends the resulting assistant turn. Both turns are returned so
      # the UI can render them without a second round-trip.
      class AssistantMessagesController < ApplicationController
        include CaregiverAuthenticatable

        def index
          conversation = find_or_create_conversation
          render json: {
            conversation_id: conversation.id,
            turns: AssistantTurnBlueprint.render_as_hash(conversation.assistant_turns.order(:created_at))
          }, status: :ok
        end

        def create
          return render json: { error: "assistant_unavailable" }, status: :forbidden unless assistant_available?

          conversation = find_or_create_conversation
          message = params[:message].to_s

          caregiver_turn = conversation.assistant_turns.create!(role: "caregiver", content: message)

          result = Domain::Ai::Gateway.assistant_reply(
            episode: current_caregiver.episode, caregiver: current_caregiver, conversation: conversation,
            language: current_caregiver.language, message: message
          )

          assistant_turn = conversation.assistant_turns.create!(
            role: "assistant",
            content: result.text,
            retrieval_refs: result.citations || [],
            guardrail_verdicts: (result.guardrail_verdicts || {}).merge(
              "routed_flag_id" => result.routed_flag_id, "degraded" => !!result.degraded
            ),
            routed: !!result.routed,
            emergency_detected: !!result.emergency_detected
          )

          Domain::Audit::Recorder.record!(
            actor: current_caregiver, action: "assistant.turn", entity: assistant_turn,
            payload: { routed: assistant_turn.routed, emergency_detected: assistant_turn.emergency_detected }
          )
          if assistant_turn.routed || assistant_turn.emergency_detected
            Domain::Analytics::Tracker.track!(episode: current_caregiver.episode, name: "assistant.turn.routed")
          end

          render json: {
            conversation_id: conversation.id,
            caregiver_turn: AssistantTurnBlueprint.render_as_hash(caregiver_turn),
            assistant_turn: AssistantTurnBlueprint.render_as_hash(assistant_turn)
          }, status: :created
        end

        # Routed-question UX, "one-tap send-to-nurse" (Section 8/M5): for
        # any assistant turn (routed or not — a caregiver may want to
        # escalate an in-scope answer they're not satisfied with too),
        # opens a manual flag tied to that turn. Idempotent-ish in intent
        # but not de-duplicated — a second tap just logs a second
        # escalation event; the cockpit's manual-flag lifecycle already
        # collapses concurrent open flags per episode (Domain::Flags::
        # Lifecycle upgrades rather than duplicates).
        def escalate
          turn = conversation_scope.find(params[:id])
          flag = Flag.create!(
            episode: current_caregiver.episode, severity: "yellow", subtype: "manual", state: "open",
            opened_at: Time.current,
            sla_deadline_at: Domain::Flags::Sla.deadline_for(episode: current_caregiver.episode, severity: "yellow", from: Time.current)
          )
          turn.update!(guardrail_verdicts: turn.guardrail_verdicts.merge("manually_escalated_flag_id" => flag.id))

          Domain::Audit::Recorder.record!(
            actor: current_caregiver, action: "assistant.turn.escalated_by_caregiver", entity: flag, payload: { turn_id: turn.id }
          )
          Domain::Flags::Broadcaster.call(flag)

          render json: { flag_id: flag.id }, status: :ok
        end

        private

        def conversation_scope
          AssistantTurn.joins(:assistant_conversation).where(assistant_conversations: { caregiver_ref: current_caregiver.id })
        end

        # Kill switch (AI_ASSISTANT_ENABLED) + consent (c) — Section 6 #5
        # and Section 8/M5: "consent-(c)-declined behavior (assistant
        # fully hidden)".
        def assistant_available?
          ENV.fetch("AI_ASSISTANT_ENABLED", "true") != "false" &&
            current_caregiver.consents.where(kind: "c", granted: true).exists?
        end

        def find_or_create_conversation
          AssistantConversation.find_or_create_by!(episode: current_caregiver.episode, caregiver: current_caregiver) do |c|
            c.language = current_caregiver.language
            c.started_at = Time.current
          end
        end
      end
    end
  end
end
