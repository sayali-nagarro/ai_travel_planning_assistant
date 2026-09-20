require "rails_helper"

RSpec.describe KnowledgeSource, type: :model do
  it "has many knowledge chunks" do
    source = described_class.create!(title: "Guide", url: "https://example.com", destination: "Singapore", source_type: "guide")
    source.knowledge_chunks.create!(chunk_index: 0, content: "Content", embedding: Array.new(32, 0.1), metadata: {})

    expect(source.knowledge_chunks.count).to eq(1)
  end

  it "requires source metadata fields" do
    source = described_class.new

    expect(source).not_to be_valid
  end
end
