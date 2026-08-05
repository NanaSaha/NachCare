module Api
  module V1
    module Staff
      # Knowledge-base CMS (Section 8/M5, FR-N15): draft -> in_review ->
      # approved (two distinct approvers), then KnowledgeChunkingJob
      # chunks+embeds the body so it becomes retrievable
      # (Domain::Ai::Retrieval only ever queries status:"approved" docs).
      class KnowledgeDocsController < ApplicationController
        before_action :authenticate_user!
        before_action :set_doc, only: [ :show, :update, :approve ]

        def index
          docs = policy_scope(KnowledgeDoc).order(:title, :language, :version)
          render json: KnowledgeDocBlueprint.render(docs), status: :ok
        end

        def show
          authorize @doc
          render json: KnowledgeDocBlueprint.render_as_hash(@doc).merge(body: @doc.body), status: :ok
        end

        def create
          doc = KnowledgeDoc.new(doc_params.merge(status: "draft", approvals: []))
          authorize doc

          if doc.save
            Domain::Audit::Recorder.record!(actor: current_user, action: "knowledge_doc.created", entity: doc, payload: {})
            render json: KnowledgeDocBlueprint.render_as_hash(doc), status: :created
          else
            render json: { errors: doc.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @doc

          if @doc.update(doc_params)
            Domain::Audit::Recorder.record!(actor: current_user, action: "knowledge_doc.updated", entity: @doc, payload: {})
            render json: KnowledgeDocBlueprint.render_as_hash(@doc), status: :ok
          else
            render json: { errors: @doc.errors.full_messages }, status: :unprocessable_content
          end
        end

        # Two-person approval (FR-N15): each call records one approver;
        # the second *distinct* approver flips status to "approved" and
        # enqueues chunking/embedding (KnowledgeDoc#approve!).
        def approve
          authorize @doc, :approve?
          newly_approved = @doc.approve!(current_user)
          Domain::Audit::Recorder.record!(actor: current_user, action: "knowledge_doc.approved", entity: @doc, payload: { newly_approved: newly_approved })
          render json: KnowledgeDocBlueprint.render_as_hash(@doc), status: :ok
        end

        private

        def set_doc
          @doc = KnowledgeDoc.find(params[:id])
        end

        def doc_params
          params.permit(:title, :language, :version, :body)
        end
      end
    end
  end
end
