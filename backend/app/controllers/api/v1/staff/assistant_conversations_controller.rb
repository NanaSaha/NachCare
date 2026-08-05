module Api
  module V1
    module Staff
      # Cockpit-facing view of a caregiver's assistant chat (Section 8/M5:
      # "routed/escalated-conversation view"). A nurse following up on an
      # AI-routed flag (Domain::Ai::AssistantPipeline creates a
      # subtype:"manual" Flag when it routes) opens this to see the full
      # exchange, not just the flag's bare metadata.
      class AssistantConversationsController < ApplicationController
        before_action :authenticate_user!

        def show
          episode = Episode.find(params[:episode_id])
          authorize episode, :show?

          conversation = episode.assistant_conversations.order(:started_at).last
          if conversation
            Domain::Audit::Recorder.record!(actor: current_user, action: "assistant_conversation.viewed", entity: conversation, payload: {})
          end

          render json: {
            conversation_id: conversation&.id,
            turns: conversation ? AssistantTurnBlueprint.render_as_hash(conversation.assistant_turns.order(:created_at)) : []
          }, status: :ok
        end
      end
    end
  end
end
