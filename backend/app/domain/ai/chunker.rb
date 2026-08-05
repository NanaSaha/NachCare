module Domain
  module Ai
    # Splits a knowledge doc's body into retrieval-sized chunks. Simple
    # paragraph-based splitting with a max-length fallback — good enough
    # for the MVP's knowledge base size; not a production-grade semantic
    # chunker (an engineering simplification, not a clinical-content
    # decision, so it isn't an ADR).
    module Chunker
      MAX_CHUNK_CHARS = 800

      def self.chunks(body)
        paragraphs = body.to_s.split(/\n{2,}/).map(&:strip).reject(&:blank?)
        paragraphs.flat_map { |p| p.length > MAX_CHUNK_CHARS ? p.scan(/.{1,#{MAX_CHUNK_CHARS}}(?:\s|\z)/m).map(&:strip) : [ p ] }
                  .reject(&:blank?)
      end
    end
  end
end
