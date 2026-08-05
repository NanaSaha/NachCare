module Domain
  module Notifications
    class Dispatcher
      ADAPTERS = {
        "webpush" => Adapters::WebPushAdapter,
        "sms" => Adapters::SmsAdapter,
        "email" => Adapters::EmailAdapter
      }.freeze

      def self.send!(caregiver:, channel:, kind:, flag: nil)
        new(caregiver:, channel:, kind:, flag:).send!
      end

      def initialize(caregiver:, channel:, kind:, flag:)
        @caregiver = caregiver
        @channel = channel
        @kind = kind
        @flag = flag
      end

      def send!
        # ADR-0008 #7: read fresh at send time, not cached, so a caregiver
        # language switch takes effect on the very next dispatch.
        body = Templates.body_for(kind: kind, language: caregiver.language)

        # Created before delivery (state optimistically "sent") so its id
        # can be embedded in the webpush payload — the service worker's
        # confirm beacon (PushConfirmWatchJob) needs to know *which*
        # attempt a "received" event is for.
        attempt = NotificationAttempt.create!(kind: kind, channel: channel, state: "sent", caregiver: caregiver, flag: flag)

        adapter = ADAPTERS.fetch(channel).new
        delivered = adapter.send!(caregiver: caregiver, body: body, notification_attempt_id: attempt.id)
        attempt.update!(state: "failed") unless delivered

        # AT-3 / M7 hardening (ADR-0009 #8, "push down" drill): "SMS
        # fallback on simulated push failure" — an *immediate* adapter
        # failure (VAPID misconfigured, push service unreachable) must not
        # sit and wait for PushConfirmWatchJob's 5-minute unconfirmed
        # window; that window only ever catches silent non-delivery, not
        # a push the adapter already knows it couldn't send. Reuses the
        # same escalate method as the unconfirmed-window path — both mean
        # "this RED push didn't get through."
        if !delivered && channel == "webpush" && kind == "red_escalation" && flag
          FallbackChain.escalate_unconfirmed_red!(flag: flag)
        end

        attempt
      end

      private

      attr_reader :caregiver, :channel, :kind, :flag
    end
  end
end
