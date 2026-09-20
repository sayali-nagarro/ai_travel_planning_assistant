module Travel
  Decision = Struct.new(:needs_knowledge, :needs_weather, :needs_currency, :reason, keyword_init: true)

  class ToolRouter
    def call(user_message:, context:)
      needs_currency = currency_query?(user_message)
      needs_weather = weather_query?(user_message, context)
      needs_knowledge = knowledge_query?(user_message, context, needs_weather:, needs_currency:)

      Decision.new(
        needs_knowledge: needs_knowledge,
        needs_weather: needs_weather,
        needs_currency: needs_currency,
        reason: explain(needs_knowledge:, needs_weather:, needs_currency:)
      )
    end

    private

    def knowledge_query?(message, context, needs_weather:, needs_currency:)
      travel_keywords = message.match?(/singapore|itinerary|attraction|neighbourhood|neighborhood|transport|culture|food|family|trip|day|visit|plan|travel/i)
      follow_up_reference = context[:previous_itinerary].present? && message.match?(/day\s*(one|two|three|1|2|3)|what if|adjust|change|rain/i)

      return true if travel_keywords || follow_up_reference
      return true if (needs_weather || needs_currency) && message.match?(/itinerary|plan|trip|family|budget|travel/i)

      false
    end

    def weather_query?(message, context)
      message.match?(/weather|forecast|rain|rainy|umbrella|outdoor|next week|this weekend/i)
    end

    def currency_query?(message)
      message.match?(/\bconvert\b|\bexchange\b|budget|equivalent|worth|rate/i) ||
        message.match?(/\b(INR|SGD|USD|EUR|GBP|AUD|JPY)\b/i) ||
        message.match?(/\bindian rupees?\b|\baustralian currency\b|\baustralian dollars?\b|\bsingapore dollars?\b|\bamerican dollars?\b|\bus currency\b|\beuropean currency\b|\bbritish pounds?\b|\bjapanese yens?\b/i)
    end

    def explain(needs_knowledge:, needs_weather:, needs_currency:)
      flags = []
      flags << "knowledge" if needs_knowledge
      flags << "weather" if needs_weather
      flags << "currency" if needs_currency
      flags.join(" + ")
    end
  end
end
