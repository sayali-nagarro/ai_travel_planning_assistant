require "rails_helper"

RSpec.describe KnowledgeChunk, type: :model do
  it "belongs to a knowledge source" do
    source = KnowledgeSource.create!(title: "Guide", url: "https://example.com", destination: "Singapore", source_type: "guide")
    chunk = described_class.create!(knowledge_source: source, chunk_index: 0, content: "Content", embedding: Array.new(32, 0.1), metadata: {})

    expect(chunk.knowledge_source).to eq(source)
  end

  it "validates presence of content and embedding" do
    chunk = described_class.new

    expect(chunk).not_to be_valid
  end
end
