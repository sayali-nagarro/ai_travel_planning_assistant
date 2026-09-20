require "digest"

module Knowledge
  class Embedder
    DIMENSIONS = 32

    TOPIC_SYNONYMS = {
      "attractions" => %w[attractions attraction sights landmarks must-visit things-to-do],
      "neighborhoods" => %w[neighborhood neighborhoods district districts area areas],
      "transport" => %w[transport transportation mrt bus buses transit train trains commute],
      "food" => %w[food hawker cuisine dining restaurants meals],
      "culture" => %w[culture cultural heritage temple museums history arts],
      "family" => %w[family families kid kids child children stroller],
      "indoor" => %w[indoor indoors museum museums aquarium mall rainy rain],
      "outdoor" => %w[outdoor outdoors park parks garden gardens nature walk walks],
      "itinerary" => %w[itinerary itineraries plan planning day days schedule],
      "weather" => %w[weather rain rainy forecast storm cloudy],
      "budget" => %w[budget cost price prices affordable cheap expensive],
      "shopping" => %w[shopping shop mall malls retail],
      "nature" => %w[nature botanic botanical greenery garden gardens],
      "waterfront" => %w[marina bay bay riverfront waterfront skyline],
      "nightlife" => %w[nightlife evening night nightspots],
      "practical" => %w[practical tips guide transport ticket card]
    }.freeze

    def embed(text)
      vector = Array.new(DIMENSIONS, 0.0)
      normalized = normalize(text)

      TOPIC_SYNONYMS.each_with_index do |(topic, keywords), index|
        score = keywords.sum { |keyword| normalized.scan(/\b#{Regexp.escape(keyword)}\b/).count }
        vector[index] = score.to_f
      end

      residual_offset = TOPIC_SYNONYMS.size
      normalized.split.each do |token|
        bucket = residual_offset + (Digest::SHA256.hexdigest(token).to_i(16) % (DIMENSIONS - residual_offset))
        vector[bucket] += 1.0
      end

      normalize_vector(vector)
    end

    private

    def normalize(text)
      text.to_s.downcase.gsub(/[^a-z0-9\s-]/, " ").gsub(/[-]/, " ")
    end

    def normalize_vector(vector)
      magnitude = Math.sqrt(vector.sum { |value| value**2 })
      return vector if magnitude.zero?

      vector.map { |value| value / magnitude }
    end
  end
end
