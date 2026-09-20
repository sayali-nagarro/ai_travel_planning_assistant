module Knowledge
  Hit = Struct.new(:chunk, :source, :score, keyword_init: true)

  class Retriever
    def initialize(embedder: Knowledge::Embedder.new, vector_store: Knowledge::VectorStore.new)
      @embedder = embedder
      @vector_store = vector_store
    end

    def call(query:, destination: "Singapore", top_k: 5)
      query_vector = embedder.embed(query)
      records = vector_store.search(query_vector:, destination:, top_k:)

      records.map do |record|
        Hit.new(
          chunk: record,
          source: record.knowledge_source,
          score: distance_score(record)
        )
      end
    end

    private

    attr_reader :embedder, :vector_store

    def distance_score(record)
      distance = record.attributes["distance"].to_f
      (1.0 - distance).round(4)
    end
  end
end
