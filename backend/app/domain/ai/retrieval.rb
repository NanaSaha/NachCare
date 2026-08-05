module Domain
  module Ai
    # Section 6 #4 stage 3 (RAG): embed the query, top-K nearest chunks
    # over *approved* knowledge_chunks, preferring the caregiver's
    # language and falling back to EN if no approved doc exists in their
    # language. Results below the similarity threshold are dropped —
    # CategoryRouter's caller treats "no results survive" as the
    # out-of-scope path (Section 6 #4: "Similarity below threshold ...
    # out-of-scope path").
    class Retrieval
      Match = Struct.new(:chunk, :doc_title, :similarity, keyword_init: true)

      def self.search(query:, language:, top_k: nil, threshold: nil)
        new.search(query:, language:, top_k:, threshold:)
      end

      def search(query:, language:, top_k: nil, threshold: nil)
        config = Gateway.config
        top_k ||= config.retrieval_top_k
        threshold ||= config.similarity_threshold

        vector = Gateway.embed!(texts: [ Redactor.redact(query) ]).first
        effective_language = language_with_approved_docs?(language) ? language : "en"

        KnowledgeChunk
          .joins(:knowledge_doc)
          .where(knowledge_docs: { status: "approved", language: effective_language })
          .nearest_neighbors(:embedding, vector, distance: "cosine")
          .limit(top_k)
          .filter_map do |chunk|
            similarity = 1 - chunk.neighbor_distance
            next if similarity < threshold

            Match.new(chunk: chunk, doc_title: chunk.knowledge_doc.title, similarity: similarity)
          end
      end

      private

      def language_with_approved_docs?(language)
        KnowledgeDoc.where(status: "approved", language: language).exists?
      end
    end
  end
end
