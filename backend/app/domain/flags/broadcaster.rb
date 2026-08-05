module Domain
  module Flags
    # Live triage queue updates over the site's FlagsChannel stream. Raw
    # attributes, not a Blueprinter render — the domain layer shouldn't
    # depend on the presentation layer; the cockpit queue re-fetches/
    # patches its row from this payload.
    class Broadcaster
      def self.call(flag)
        site_id = flag.episode.patient.site_ref
        ActionCable.server.broadcast("flags_site_#{site_id}", {
          id: flag.id, severity: flag.severity, state: flag.state, breach: flag.breach,
          sla_deadline_at: flag.sla_deadline_at, episode_ref: flag.episode_ref
        })
      end
    end
  end
end
