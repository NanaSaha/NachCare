module Api
  module V1
    class SitesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_site, only: [ :show, :update ]

      def index
        sites = policy_scope(Site)
        render json: SiteBlueprint.render(sites), status: :ok
      end

      def show
        authorize @site
        render json: SiteBlueprint.render(@site), status: :ok
      end

      def create
        site = Site.new(site_params)
        authorize site

        if site.save
          Domain::Audit::Recorder.record!(actor: current_user, action: "site.created", entity: site, payload: site_params.to_h)
          render json: SiteBlueprint.render(site), status: :created
        else
          render json: { errors: site.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        authorize @site

        if @site.update(site_params)
          Domain::Audit::Recorder.record!(actor: current_user, action: "site.updated", entity: @site, payload: site_params.to_h)
          render json: SiteBlueprint.render(@site), status: :ok
        else
          render json: { errors: @site.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_site
        @site = Site.find(params[:id])
      end

      def site_params
        params.require(:site).permit(:name, :timezone, :sla_red_minutes, :sla_yellow_minutes)
      end
    end
  end
end
