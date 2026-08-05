# Live triage queue updates (M3). One stream per site — a nurse only ever
# needs their own site's flags, and this keeps the fan-out bounded without
# per-user streams.
class FlagsChannel < ApplicationCable::Channel
  def subscribed
    site_id = current_user.site_ref
    reject unless site_id

    stream_from "flags_site_#{site_id}"
  end
end
