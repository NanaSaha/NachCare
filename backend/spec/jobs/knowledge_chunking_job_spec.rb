require "rails_helper"

RSpec.describe KnowledgeChunkingJob do
  it "chunks and embeds an approved doc's body" do
    doc = create(:knowledge_doc, status: "approved", body: "First paragraph about fluids.\n\nSecond paragraph about diet.")

    described_class.new.perform(doc.id)

    expect(doc.knowledge_chunks.count).to eq(2)
    expect(doc.knowledge_chunks.first.embedding.size).to eq(1024)
  end

  it "does nothing for a non-approved doc" do
    doc = create(:knowledge_doc, status: "draft", body: "some text")

    described_class.new.perform(doc.id)

    expect(doc.knowledge_chunks.count).to eq(0)
  end

  it "replaces existing chunks rather than accumulating duplicates on re-run" do
    doc = create(:knowledge_doc, status: "approved", body: "Only paragraph.")
    described_class.new.perform(doc.id)
    described_class.new.perform(doc.id)

    expect(doc.knowledge_chunks.count).to eq(1)
  end
end
