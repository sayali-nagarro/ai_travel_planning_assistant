module Ai
  class LocalClient
    def generate(messages:, system_prompt:, context:, retrieved_documents:, tool_results:)
      request = messages.last.respond_to?(:content) ? messages.last.content.to_s : messages.last.to_s
      response_sections = []

      if context[:trip_duration_days].present?
        response_sections << "Trip overview: a #{context[:trip_duration_days]}-day Singapore plan for #{context[:travel_party] || 'your trip'}."
      else
        response_sections << "Trip overview: a Singapore travel plan tailored to your request."
      end

      if retrieved_documents.any?
        response_sections << "Based on the Singapore knowledge base:"
        retrieved_documents.first(3).each do |document|
          response_sections << "- #{document[:title]}: #{document[:summary]}"
        end
      else
        response_sections << "I could not retrieve enough destination knowledge to ground a detailed recommendation."
      end

      weather = tool_results.find { |tool| tool[:name] == "weather" }
      if weather && weather[:status] == :success
        response_sections << "Current information from Weather MCP: #{summarize_weather(weather[:data])}"
      elsif weather
        response_sections << "Weather MCP was unavailable: #{weather[:error]}"
      end

      currency = tool_results.find { |tool| tool[:name] == "currency" }
      if currency && currency[:status] == :success
        response_sections << "Current information from Currency MCP: #{summarize_currency(currency[:data])}"
      elsif currency
        response_sections << "Currency MCP was unavailable: #{currency[:error]}"
      end

      if request.match?(/itinerary|plan|day|trip/i)
        response_sections << itinerary_template(context:, retrieved_documents:, tool_results:)
      else
        response_sections << recommendation_template(context:, retrieved_documents:, tool_results:)
      end

      response_sections.join("\n\n")
    end

    private

    def itinerary_template(context:, retrieved_documents:, tool_results:)
      weather = tool_results.find { |tool| tool[:name] == "weather" }
      indoor_backups = retrieved_documents.select { |document| document[:tags].include?("indoor") || document[:tags].include?("family") }
      outdoor_options = retrieved_documents.select { |document| document[:tags].include?("outdoor") || document[:tags].include?("nature") }
      trip_days = context[:trip_duration_days].to_i
      trip_days = 3 if trip_days <= 0

      day_plans = [
        [
          "Morning: Marina Bay and skyline walk.",
          "Afternoon: Gardens by the Bay or another outdoor highlight.",
          "Evening: Hawker centre dinner and waterfront views.",
          "If it rains: switch to #{indoor_backups.first&.dig(:title) || 'an indoor museum or aquarium'}."
        ],
        [
          "Morning: Chinatown, Little India, or Kampong Glam for culture and food.",
          "Afternoon: MRT-based neighborhood hopping to keep transfers short.",
          "Evening: indoor cultural activity if the forecast is wet.",
          "Weather note: #{weather.present? ? 'use the forecast below to shift outdoor time earlier in the day.' : 'no weather data available.'}"
        ],
        [
          "Morning: Sentosa, Singapore Botanic Gardens, or another family-friendly choice.",
          "Afternoon: shopping, aquarium, museum, or rest time.",
          "Evening: flexible final dinner and departure buffer.",
          "Outdoor backup: #{outdoor_options.first&.dig(:title) || 'a parks-and-gardens option'}."
        ],
        [
          "Morning: choose a calmer neighborhood such as Dempsey, Tiong Bahru, or Joo Chiat.",
          "Afternoon: add a museum, science attraction, or a long lunch break.",
          "Evening: wrap up with a final hawker or waterfront meal.",
          "Weather note: keep this as a flexible buffer day for storms or travel fatigue."
        ],
        [
          "Morning: keep this as an easy final half-day for shopping or a last cafe stop.",
          "Afternoon: airport transfer or a short activity near your hotel.",
          "Evening: no-pressure departure or rest window.",
          "Backup: use this day to absorb any weather delays earlier in the trip."
        ]
      ]

      trip_days = [ trip_days, 1 ].max

      days = Array.new(trip_days) do |index|
        plan = day_plans[index % day_plans.length]

        [
          "Day #{index + 1}",
          "- #{plan[0]}",
          "- #{plan[1]}",
          "- #{plan[2]}",
          "- #{plan[3]}"
        ]
      end.flatten

      days << "Why this works: the plan matches the trip length, groups sights by neighborhood, mixes indoor and outdoor options, and leaves room for weather adjustments across longer stays."
      days.join("\n")
    end

    def recommendation_template(context:, retrieved_documents:, tool_results:)
      [
        "Recommendation: combine the retrieved Singapore knowledge with your preferences for a balanced plan.",
        context[:travel_party].present? ? "Travel party: #{context[:travel_party]}" : nil,
        context[:budget].present? ? "Budget context: #{context[:budget]} #{context[:budget_currency]}" : nil,
        retrieved_documents.first(2).map { |document| "- #{document[:title]}: #{document[:summary]}" }
      ].flatten.compact.join("\n")
    end

    def summarize_weather(data)
      data[:forecast].map do |day|
        "#{day[:date]}: #{day[:condition]}, high #{day[:temperature_max_c]}C, rain #{day[:precipitation_probability]}%"
      end.join(" | ")
    end

    def summarize_currency(data)
      formatted = format("%.2f", data[:converted_amount].to_f)
      "#{data[:amount]} #{data[:from]} = #{formatted} #{data[:to]} at rate #{format('%.4f', data[:rate].to_f)}"
    end
  end
end
