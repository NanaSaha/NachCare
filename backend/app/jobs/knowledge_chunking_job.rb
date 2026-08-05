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
  end
end
