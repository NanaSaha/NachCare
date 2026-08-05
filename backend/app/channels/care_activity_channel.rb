# Nurse requirement #3 (ADR-0010): live caregiver activity (check-ins,
# medication doses) on the cockpit patient-detail page. One stream per
# episode — unlike FlagsChannel (one stream per site, for the whole triage
# queue), a patient-detail page only ever cares about its own episode.
class CareActivityChannel < ApplicationCable::Channel
  def subscribed
    episode = Episode.includes(:patient).find_by(id: params[:episode_id])
    return reject unless episode

    site_id = episode.patient.site_ref
    allowed = current_user.role == "sysadmin" || current_user.site_ref == site_id
    return reject unless allowed

    stream_from "care_activity_episode_#{episode.id}"
  end
end
