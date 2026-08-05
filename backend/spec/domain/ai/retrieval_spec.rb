require "rails_helper"

RSpec.describe Domain::Ai::Retrieval do
  def vector_for(text) = Domain::Ai::Providers::StubProvider.new.embed(texts: [ text ]).first

  it "returns matches only from approved docs" do
    approved = create(:knowledge_doc, status: "approved", language: "en", title: "Fluid Tracking Guide")
    draft = create(:knowledge_doc, status: "draft", language: "en", title: "Unapproved Draft")
    create(:knowledge_chunk, knowledge_doc: approved, chunk: "track your fluids", embedding: vector_for("track your fluids"))
    create(:knowledge_chunk, knowledge_doc: draft, chunk: "track your fluids too", embedding: vector_for("track your fluids too"))

    matches = described_class.search(query: "track your fluids", language: "en", threshold: -1.0)

    expect(matches.map(&:doc_title)).to eq([ "Fluid Tracking Guide" ])
  end

  it "falls back to EN when no approved doc exists in the requested language" do
    approved_en = create(:knowledge_doc, status: "approved", language: "en", title: "EN Guide")
    create(:knowledge_chunk, knowledge_doc: approved_en, chunk: "diet guidance", embedding: vector_for("diet guidance"))

    matches = described_class.search(query: "diet guidance", language: "de", threshold: -1.0)

    expect(matches.map(&:doc_title)).to eq([ "EN Guide" ])
  end

  it "drops matches below the similarity threshold" do
    approved = create(:knowledge_doc, status: "approved", language: "en", title: "Unrelated Guide")
    create(:knowledge_chunk, knowledge_doc: approved, chunk: "completely unrelated content", embedding: vector_for("completely unrelated content"))

    matches = described_class.search(query: "track your fluids", language: "en", threshold: 0.999)

    expect(matches).to be_empty
  end

  it "returns at most top_k matches" do
    approved = create(:knowledge_doc, status: "approved", language: "en", title: "Guide")
    8.times { |i| create(:knowledge_chunk, knowledge_doc: approved, chunk: "chunk #{i}", embedding: vector_for("chunk #{i}")) }

    matches = described_class.search(query: "chunk 0", language: "en", top_k: 3, threshold: -1.0)

    expect(matches.size).to eq(3)
  end
end
