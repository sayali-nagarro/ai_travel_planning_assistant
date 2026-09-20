module Knowledge
  class Catalog
    Source = Struct.new(:title, :url, :destination, :source_type, :sections, :metadata, keyword_init: true)

    def self.singapore_sources
      [
        Source.new(
          title: "Wikivoyage Singapore Travel Guide",
          url: "https://en.wikivoyage.org/wiki/Singapore",
          destination: "Singapore",
          source_type: "wikivoyage",
          metadata: { extracted_topics: %w[neighborhoods transport food culture families] },
          sections: [
            {
              title: "Overview and neighborhoods",
              content: "Singapore is compact and easy to navigate. Chinatown, Little India, Kampong Glam, Marina Bay, Orchard, and Sentosa each offer a distinct experience. Use the MRT and buses for efficient point-to-point travel, and plan by neighborhood to reduce transit time."
            },
            {
              title: "Food and cultural guidance",
              content: "Hawker centres are one of the strongest reasons to visit. Expect Malay, Chinese, Indian, and Peranakan influences. Temple streets, heritage lanes, and museum districts make good cultural stops when the weather is hot or wet."
            },
            {
              title: "Indoor and outdoor highlights",
              content: "Gardens by the Bay, the Singapore Botanic Gardens, and MacRitchie are strong outdoor options. For indoor or rainy-day plans, consider the National Gallery, ArtScience Museum, Jewel Changi, and aquarium experiences."
            }
          ]
        ),
        Source.new(
          title: "Visit Singapore - Things to Do",
          url: "https://www.visitsingapore.com/en/see-do/",
          destination: "Singapore",
          source_type: "tourism_board",
          metadata: { extracted_topics: %w[attractions family indoor outdoor neighbourhoods] },
          sections: [
            {
              title: "Must-visit attractions",
              content: "Marina Bay, Gardens by the Bay, Singapore Flyer, Chinatown, Sentosa, and the Singapore Botanic Gardens provide a balanced first trip. Combine landmark viewing with neighborhood wandering and hawker food stops."
            },
            {
              title: "Family-friendly and indoor options",
              content: "In Singapore, families can mix museums, aquariums, science attractions, and parks with playgrounds. Indoor destinations are useful when humidity or rain interrupts outdoor sightseeing, and they work especially well for family-friendly indoor activities."
            },
            {
              title: "Outdoor activity planning",
              content: "Plan outdoor time earlier in the day, keep water handy, and leave room to switch to indoor alternatives if thunderstorms arrive. Gardens, skyline walks, and riverfront areas are best paired with flexible backup options."
            }
          ]
        ),
        Source.new(
          title: "Visit Singapore - Travel Planning and Itineraries",
          url: "https://www.visitsingapore.com/en/plan-your-trip/",
          destination: "Singapore",
          source_type: "tourism_board",
          metadata: { extracted_topics: %w[itineraries transport budget weather family] },
          sections: [
            {
              title: "Three-day planning pattern",
              content: "A strong three-day visit usually pairs Marina Bay and gardens on one day, heritage neighborhoods and food on another, and a family or leisure day that can adapt to rain. Keep transfer time low by grouping places by district."
            },
            {
              title: "Transport and practical tips",
              content: "The MRT is the fastest citywide option for most travelers. Buses fill gaps between stations. For families and first-timers, preloading a transit card and planning by zone makes days feel calmer and more flexible."
            },
            {
              title: "Budget and weather backup",
              content: "Singapore can be explored at many price points. When rain is likely, build indoor alternatives into the plan rather than treating weather as an afterthought."
            }
          ]
        )
      ]
    end
  end
end
