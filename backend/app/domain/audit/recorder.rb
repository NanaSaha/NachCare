module Domain
  module Audit
    # Single entry point for writing to the append-only audit spine (R6).
    # Every clinically relevant action should go through `Recorder.record!`
    # rather than inserting into AuditEvent directly, so the payload hash
    # and actor/entity resolution stay consistent everywhere.
    class Recorder
      class UnknownActor < StandardError; end

      SYSTEM_ACTORS = %i[system ai].freeze

      def self.record!(actor:, action:, entity:, payload: {})
        new.record!(actor:, action:, entity:, payload:)
      end

      def record!(actor:, action:, entity:, payload: {})
        canonical_payload = canonicalize(payload)
        actor_type, actor_ref = resolve_actor(actor)
        entity_type, entity_ref = resolve_entity(entity)

        AuditEvent.create!(
          actor_type: actor_type,
          actor_ref: actor_ref,
          action: action.to_s,
          entity_type: entity_type,
          entity_ref: entity_ref,
          payload: canonical_payload,
          payload_sha256: Digest::SHA256.hexdigest(JSON.generate(canonical_payload)),
          created_at: Time.current
        )
      end

      private

      def resolve_actor(actor)
        return [ actor.to_s, nil ] if SYSTEM_ACTORS.include?(actor)

        case actor
        when User then [ "user", actor.id.to_s ]
        when Caregiver then [ "caregiver", actor.id.to_s ]
        else
          raise UnknownActor, "cannot resolve actor: #{actor.inspect}"
        end
      end

      def resolve_entity(entity)
        [ entity.class.name.underscore, entity.id.to_s ]
      end

      # Recursively sorts hash keys so the same logical payload always
      # produces the same JSON string, and therefore the same payload_sha256,
      # regardless of insertion order.
      def canonicalize(obj)
        case obj
        when Hash
          obj.map { |k, v| [ k.to_s, canonicalize(v) ] }.sort_by(&:first).to_h
        when Array
          obj.map { |v| canonicalize(v) }
        else
          obj
        end
      end
    end
  end
end
