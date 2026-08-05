module Api
  module V1
    module Staff
      # Med type-ahead for the enrollment screen (FR-N10/11). Not
      # per-patient/per-site data — any authenticated staff member can
      # search it, no Pundit policy needed. Free-text fallback for anything
      # not in the local PLACEHOLDER list lives client-side (the enrollment
      # form accepts an arbitrary medication name if nothing matches).
      class DrugsController < ApplicationController
        before_action :authenticate_user!

        MAX_RESULTS = 20

        def index
          query = params[:q].to_s.strip
          drugs = query.blank? ? Drug.none : Drug.where("name ILIKE ?", "%#{Drug.sanitize_sql_like(query)}%")
          drugs = drugs.order(:name).limit(MAX_RESULTS)

          render json: DrugBlueprint.render(drugs), status: :ok
        end
      end
    end
  end
end
