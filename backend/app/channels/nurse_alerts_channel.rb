# Product-owner feedback item #4 (ADR-0011): site-wide nurse alert stream
# feeding the cockpit's persistent nav bell. One stream per site, same
# fan-out scope/shape as FlagsChannel (M3) — sysadmins (no site_ref) are
# rejected here too, matching FlagsChannel's existing behavior exactly
# rather than inventing different sysadmin handling for a structurally
# identical channel.
class NurseAlertsChannel < ApplicationCable::Channel
  def subscribed
    site_id = current_user.site_ref
    reject unless site_id

    stream_from "nurse_alerts_site_#{site_id}"
  end
end
