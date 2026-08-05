module Api
  module V1
    module Staff
      # Nurse -> caregiver messages (Section 8/M4): template bank + a
      # translate-assist "show-before-send" flow. #preview never persists
      # anything — it only returns what the nurse would see before
      # confirming; #create is the actual send, and always takes whatever
      # body_translated the nurse reviewed/edited in the preview step, not
      # a re-computed one, so what was shown is exactly what gets sent.
      class MessagesController < ApplicationController
        before_action :authenticate_user!
        before_action :set_episode

        def index
          messages = policy_scope(Message).where(episode: @episode).order(created_at: :asc)
          render json: MessageBlueprint.render(messages), status: :ok
        end

        def preview
          authorize @episode.messages.new, :create?

          body_source = resolved_body_source
          target_language = params[:language].presence || @episode.caregivers.first&.language || "en"

          render json: {
            body_source: body_source,
            body_translated: Domain::Messages::TranslateAssist.suggest(body_source: body_source, target_language: target_language),
            language: target_language
          }, status: :ok
        end

        def create
          message = @episode.messages.new(
            sender: "nurse",
            template_key: params[:template_key].presence,
            body_source: resolved_body_source,
            body_translated: params[:body_translated].presence,
            language: params[:language].presence || "en"
          )
          authorize message

          if message.save
            Domain::Audit::Recorder.record!(actor: current_user, action: "message.sent", entity: message, payload: {})
            render json: MessageBlueprint.render_as_hash(message), status: :created
          else
            render json: { errors: message.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_episode
          @episode = Episode.find(params[:episode_id])
        end

        def resolved_body_source
          return Domain::Messages::Templates::BANK.fetch(params[:template_key]) if params[:template_key].present?

          params[:body_source].to_s
        end
      end
    end
  end
end
