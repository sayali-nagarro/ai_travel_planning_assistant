module Knowledge
  class Chunker
    def call(sections:, source:)
      sections.each_with_index.map do |section, index|
        content = [ section[:title], section[:content] ].join("\n\n")

        {
          chunk_index: index,
          content: content.strip,
          metadata: {
            section_title: section[:title],
            source_title: source.title,
            source_url: source.url,
            destination: source.destination
          }
        }
      end
    end
  end
end
