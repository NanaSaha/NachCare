module Api
  module V1
    module Caregiver
      # Care-team page (Section 8/M6, R4): the frontend's static emergency
      # block renders with zero HTTP calls (R4 spec — see
      # projects/shared/src/lib/emergency-block), so this endpoint only
      # supplies the *optional* supplementary info (site name) the page
      # shows below it. No individual nurse contact data — the real
      # contact channel is the existing nurse<->caregiver messages feature
      # (M4), not a phone number surfaced here.
      class CareTeamController < ApplicationController
        include CaregiverAuthenticatable

        def show
          site = current_caregiver.episode.patient.site
          render json: { site_name: site.name }, status: :ok
        end
      end
    end
  end
end
