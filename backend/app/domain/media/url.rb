module Domain
  module Media
    # Single place that turns an ActiveStorage attachment into an absolute
    # URL for the frontend (img/video src) — ADR-0011. The blob's URL path
    # contains only a signed random key, never a patient identifier or
    # filename, so this is safe against R5 (no PHI in URLs) the same way
    # every other staff-authenticated JSON field already is.
    module Url
      def self.for(attachment)
        return nil unless attachment&.attached?

        Rails.application.routes.url_helpers.rails_blob_url(attachment)
      end
    end
  end
end
