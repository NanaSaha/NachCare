require "csv"

module Api
  module V1
    module Staff
      # AN-1 pilot metrics + FR-N12 export (Section 8/M7, ADR-0009). One
      # action, three formats via the `.csv`/`.pdf` route-extension
      # (`params[:format]`) — not `respond_to`/Accept-header negotiation,
      # which 406s in ActionController::API against plain rack-test
      # requests with no Accept header; every other controller in this app
      # renders JSON unconditionally for the same reason. All three
      # formats render the exact same `PilotMetrics.compute` result, never
      # re-derived per format.
      class AnalyticsController < ApplicationController
        before_action :authenticate_user!

        DEFAULT_WINDOW_DAYS = 30

        def pilot_metrics
          site = Site.find(params[:site_id].presence || current_user.site_ref)
          authorize site, :show?

          metrics = Domain::Analytics::PilotMetrics.compute(site: site, from: range_from, to: range_to).to_h

          case params[:format]
          when "csv"
            send_data pilot_metrics_csv(metrics), filename: "nachcare-pilot-metrics-#{site.id}.csv", type: "text/csv"
          when "pdf"
            pdf = Domain::Analytics::PilotMetricsPdf.render(site: site, metrics: metrics)
            send_data pdf, filename: "nachcare-pilot-metrics-#{site.id}.pdf", type: "application/pdf", disposition: "inline"
          else
            render json: metrics, status: :ok
          end
        end

        private

        def range_from
          params[:from].presence ? Date.parse(params[:from]) : DEFAULT_WINDOW_DAYS.days.ago.to_date
        end

        def range_to
          params[:to].presence ? Date.parse(params[:to]) : Date.current
        end

        def pilot_metrics_csv(metrics)
          CSV.generate do |csv|
            csv << [ "metric", "value" ]
            metrics.each { |key, value| csv << [ key, value ] }
          end
        end
      end
    end
  end
end
