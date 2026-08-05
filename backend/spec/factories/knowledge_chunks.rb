FactoryBot.define do
  factory :knowledge_chunk do
    knowledge_doc
    chunk { "Some approved guidance chunk text." }
    embedding { Array.new(1024, 0.0) }
  end
end
