module Api
  module V1
    module Caregiver
      # Learn curriculum (Section 8/M6): approved items only, each flagged
      # with its unlock state (Domain::Learn::Unlocker, ADR-0008 #2) and
      # whether this caregiver's episode already has a completion event for
      # it. `variant_for` falls back to English if their language has no
      # authored copy yet.
      class ContentItemsController < ApplicationController
        include CaregiverAuthenticatable

        def index
          episode = current_caregiver.episode
          language = current_caregiver.language
          items = ContentItem.where(status: "approved").order(:week_no, :kind)
          completed_refs = completed_content_item_refs(episode)

          render json: items.map { |item| item_json(item, episode, language, completed_refs) }, status: :ok
        end

        def complete
          episode = current_caregiver.episode
          item = ContentItem.where(status: "approved").find(params[:id])

          unless completed_content_item_refs(episode).include?(item.id)
            Domain::Analytics::Tracker.track!(
              episode: episode, name: "content_item.completed", properties: { "content_item_ref" => item.id }
            )
          end

          language = current_caregiver.language
          render json: item_json(item, episode, language, completed_content_item_refs(episode)), status: :ok
        end

        private

        def item_json(item, episode, language, completed_refs)
          variant = item.variant_for(language)
          {
            id: item.id, kind: item.kind, week_no: item.week_no,
            title: variant["title"], body: variant["body"],
            unlocked: Domain::Learn::Unlocker.unlocked?(item: item, episode: episode),
            completed: completed_refs.include?(item.id)
          }
        end

        def completed_content_item_refs(episode)
          AnalyticsEvent
            .where(episode_pseudonym_ref: episode.patient.pseudonym_code, name: "content_item.completed")
            .pluck(:properties)
            .filter_map { |p| p["content_item_ref"] }
            .to_set
        end
      end
    end
  end
end
