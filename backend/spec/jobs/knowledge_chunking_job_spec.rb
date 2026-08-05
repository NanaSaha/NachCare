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

  it "leaves the doc un-embedded instead of raising when every AI provider fails" do
    doc = create(:knowledge_doc, status: "approved", body: "Some text.")
    allow(Domain::Ai::Gateway).to receive(:embed!).and_raise(Domain::Ai::Gateway::AllProvidersFailed, "all providers failed for embed")

    expect { described_class.new.perform(doc.id) }.not_to raise_error
    expect(doc.knowledge_chunks.count).to eq(0)
  end
end
