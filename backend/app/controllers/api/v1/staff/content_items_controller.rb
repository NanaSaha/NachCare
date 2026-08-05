module Api
  module V1
    module Staff
      # Learn curriculum CMS (Section 8/M6, ADR-0008 #1): draft -> in_review
      # -> approved (two distinct approvers), mirroring KnowledgeDocsController
      # (FR-N15) exactly. API-only, no cockpit authoring/approval screen —
      # same time-scoping precedent as M5's knowledge-base CMS.
      class ContentItemsController < ApplicationController
        before_action :authenticate_user!
        before_action :set_item, only: [ :show, :update, :approve ]

        def index
          items = policy_scope(ContentItem).order(:week_no, :kind)
          render json: ContentItemBlueprint.render(items), status: :ok
        end

        def show
          authorize @item
          render json: ContentItemBlueprint.render_as_hash(@item).merge(language_variants: @item.language_variants), status: :ok
        end

        def create
          item = ContentItem.new(item_params.merge(status: "draft", approvals: []))
          authorize item

          if item.save
            Domain::Audit::Recorder.record!(actor: current_user, action: "content_item.created", entity: item, payload: {})
            render json: ContentItemBlueprint.render_as_hash(item), status: :created
          else
            render json: { errors: item.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @item

          if @item.update(item_params)
            Domain::Audit::Recorder.record!(actor: current_user, action: "content_item.updated", entity: @item, payload: {})
            render json: ContentItemBlueprint.render_as_hash(@item), status: :ok
          else
            render json: { errors: @item.errors.full_messages }, status: :unprocessable_content
          end
        end

        def approve
          authorize @item, :approve?
          newly_approved = @item.approve!(current_user)
          Domain::Audit::Recorder.record!(actor: current_user, action: "content_item.approved", entity: @item, payload: { newly_approved: newly_approved })
          render json: ContentItemBlueprint.render_as_hash(@item), status: :ok
        end

        private

        def set_item
          @item = ContentItem.find(params[:id])
        end

        def item_params
          params.permit(:kind, :week_no, language_variants: {})
        end
      end
    end
  end
end
