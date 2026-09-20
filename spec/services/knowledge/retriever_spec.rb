require "rails_helper"

RSpec.describe Knowledge::Retriever do
  before do
    Knowledge::Importer.new.call
  end

  it "returns relevant Singapore chunks with source metadata" do
    hits = described_class.new.call(query: "family-friendly indoor activities in Singapore", destination: "Singapore", top_k: 3)

    expect(hits).not_to be_empty
    expect(hits.map(&:source).map(&:title)).to include("Visit Singapore - Things to Do")
    expect(hits.first.chunk.content).to include("Singapore")
  end

  it "respects top_k" do
    hits = described_class.new.call(query: "Singapore itinerary", destination: "Singapore", top_k: 2)

    expect(hits.size).to eq(2)
  end
end
