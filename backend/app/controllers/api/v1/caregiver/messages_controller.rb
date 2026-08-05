module Api
  module V1
    module Caregiver
      class MessagesController < ApplicationController
        include CaregiverAuthenticatable

        def index
          messages = current_caregiver.episode.messages.order(created_at: :asc)
          render json: MessageBlueprint.render(messages), status: :ok
        end

        # Caregiver requirement #3 (post-M7 feedback round, ADR-0011): a
        # caregiver-authored status update, with an optional image/video
        # attachment, to the care team. `Message.SENDERS` already listed
        # "caregiver" (M4/M5) but no caregiver-facing endpoint existed to
        # actually create one — this is that endpoint.
        def create
          message = current_caregiver.episode.messages.new(
            sender: "caregiver",
            body_source: params[:body_source].to_s,
            language: current_caregiver.language.presence || "en"
          )
          message.media.attach(params[:media]) if params[:media].present?

          if message.save
            Domain::Audit::Recorder.record!(actor: current_caregiver, action: "message.sent", entity: message, payload: {})
            Domain::NurseAlerts::Broadcaster.message!(message)
            render json: MessageBlueprint.render_as_hash(message), status: :created
          else
            render json: { errors: message.errors.full_messages }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
