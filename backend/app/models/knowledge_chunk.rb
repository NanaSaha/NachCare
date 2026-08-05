class KnowledgeChunk < ApplicationRecord
  belongs_to :knowledge_doc, foreign_key: :doc_ref, inverse_of: :knowledge_chunks

  has_neighbors :embedding, dimensions: 1024

  validates :chunk, presence: true
end
