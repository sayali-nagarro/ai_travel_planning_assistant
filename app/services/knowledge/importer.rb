module Knowledge
  class Importer
    def initialize(catalog: Knowledge::Catalog.new, chunker: Knowledge::Chunker.new, embedder: Knowledge::Embedder.new)
      @catalog = catalog
      @chunker = chunker
      @embedder = embedder
    end

    def call
      KnowledgeSource.transaction do
        KnowledgeSource.destroy_all

        Knowledge::Catalog.singapore_sources.each do |source_data|
          source = KnowledgeSource.create!(
            title: source_data.title,
            url: source_data.url,
            destination: source_data.destination,
            source_type: source_data.source_type,
            metadata: source_data.metadata
          )

          chunker.call(sections: source_data.sections, source: source_data).each do |chunk|
            source.knowledge_chunks.create!(
              chunk_index: chunk[:chunk_index],
              content: chunk[:content],
              embedding: embedder.embed(chunk[:content]),
              metadata: chunk[:metadata]
            )
          end
        end
      end
    end

    private

    attr_reader :catalog, :chunker, :embedder
  end
end
