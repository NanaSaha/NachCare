# Section 8/M5: "knowledge-base CMS with two-person approval (FR-N15) +
# chunking/embedding job on approve." Runs once a KnowledgeDoc reaches
# `approved` (two distinct approvals — KnowledgeDoc#approve!). Replaces
# any existing chunks for the doc so re-approving an edited/new version
# doesn't leave stale chunks behind.
class KnowledgeChunkingJob
  include Sidekiq::Job

  def perform(knowledge_doc_id)
    doc = KnowledgeDoc.find(knowledge_doc_id)
    return unless doc.approved?

    doc.knowledge_chunks.destroy_all

    texts = Domain::Ai::Chunker.chunks(doc.body)
    return if texts.empty?

    vectors = Domain::Ai::Gateway.embed!(texts: texts)
    texts.zip(vectors).each do |text, vector|
      doc.knowledge_chunks.create!(chunk: text, embedding: vector)
    end
  rescue Domain::Ai::Gateway::AllProvidersFailed => e
    # Same degrade-gracefully pattern every other AI task in app/domain/ai
    # already follows (Gateway::AllProvidersFailed is expected, not
    # exceptional, when no provider is credentialed — e.g. this demo's
    # production ai.yml block, which has no stub fallback, ADR-0014). The
    # doc stays approved but un-embedded: RAG retrieval just won't surface
    # it until it's re-approved once real credentials exist. Without this
    # rescue, seeding/approving any doc with no AI provider configured
    # would hard-crash (discovered via a real db:prepare dry run against
    # a production-shaped container, ADR-0016).
    Rails.logger.warn(
      "KnowledgeChunkingJob: doc=#{knowledge_doc_id} left un-embedded, " \
      "all AI providers failed (#{e.message})"
    )
  end
end
