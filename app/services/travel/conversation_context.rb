module Travel
  class ConversationContext
    def build(conversation:, user_message:)
      preferences = conversation.preferences.deep_stringify_keys
      extracted = extract_preferences(user_message)
      merged = preferences.deep_stringify_keys.deep_merge(extracted.deep_stringify_keys)

      {
        destination: merged["destination"] || merged[:destination] || "Singapore",
        travel_party: merged["travel_party"] || merged[:travel_party],
        party_size: merged["party_size"] || merged[:party_size],
        children_ages: merged["children_ages"] || merged[:children_ages] || [],
        budget: merged["budget"] || merged[:budget],
        budget_currency: merged["budget_currency"] || merged[:budget_currency],
        trip_duration_days: merged["trip_duration_days"] || merged[:trip_duration_days],
        travel_window: merged["travel_window"] || merged[:travel_window],
        interests: Array(merged["interests"] || merged[:interests]).compact,
        previous_itinerary: merged["previous_itinerary"] || merged[:previous_itinerary],
        preferences: merged
      }
    end

    def persist!(conversation:, user_message:, assistant_response: nil)
      preferences = conversation.preferences.deep_dup
      extracted = extract_preferences(user_message)
      merged = preferences.deep_stringify_keys.deep_merge(extracted.deep_stringify_keys)

      if assistant_response && assistant_response[:itinerary_summary].present?
        merged["previous_itinerary"] = assistant_response[:itinerary_summary]
      end

      conversation.update!(preferences: merged)
    end

    private

    def extract_preferences(text)
      extracted = {
        destination: text.match?(/singapore/i) ? "Singapore" : nil,
        travel_party: travel_party(text),
        party_size: party_size(text),
        children_ages: children_ages(text),
        budget: budget_amount(text),
        budget_currency: budget_currency(text),
        trip_duration_days: trip_duration_days(text),
        travel_window: travel_window(text),
        interests: interests(text)
      }

      extracted.compact
    end

    def travel_party(text)
      return "family" if text.match?(/wife|husband|son|daughter|child|children|family/i)

      return "couple" if text.match?(/wife|husband|partner|spouse|couple/i)

      nil
    end

    def party_size(text)
      adults = 2 if text.match?(/wife|husband|partner|spouse|couple/i)
      children = text.scan(/\b(?:son|daughter|child|children|kid|kids)\b/i).size
      size = adults.to_i + children
      size.positive? ? size : nil
    end

    def children_ages(text)
      text.scan(/(\d+)\s*-?year[- ]old/i).flatten.map(&:to_i)
    end

    def budget_amount(text)
      match = text.match(/(?:INR|SGD|USD|EUR|GBP|AUD|JPY)\s?([\d,]+(?:\.\d+)?)/i)
      return unless match

      match[1].delete(",").to_f
    end

    def budget_currency(text)
      match = text.match(/\b(INR|SGD|USD|EUR|GBP|AUD|JPY)\b/i)
      match&.[](1)&.upcase
    end

    def trip_duration_days(text)
      match = text.match(/(\d+)\s*[- ]?(?:day|days|nights)/i)
      return match&.[](1)&.to_i if match

      month_match = text.match(/(\d+)\s*[- ]?(?:month|months)/i)
      return month_match&.[](1)&.to_i * 30 if month_match

      word_match = text.match(/\b(one|two|three|four|five|six|seven|eight|nine|ten)\s*[- ]?(?:day|days|night|nights)\b/i)
      return nil unless word_match

      {
        "one" => 1,
        "two" => 2,
        "three" => 3,
        "four" => 4,
        "five" => 5,
        "six" => 6,
        "seven" => 7,
        "eight" => 8,
        "nine" => 9,
        "ten" => 10
      }[word_match[1].downcase]
    end

    def travel_window(text)
      return "next week" if text.match?(/next week/i)
      return "this weekend" if text.match?(/this weekend/i)
      return "tomorrow" if text.match?(/tomorrow/i)

      nil
    end

    def interests(text)
      interests = []
      interests << "culture" if text.match?(/culture|heritage|history|museum|temple/i)
      interests << "family" if text.match?(/family|child|children|kids/i)
      interests << "indoor" if text.match?(/indoor|rain|weather/i)
      interests << "outdoor" if text.match?(/outdoor|park|garden|nature/i)
      interests << "food" if text.match?(/food|hawker|eat|dining/i)
      interests << "shopping" if text.match?(/shopping|mall|retail/i)
      interests.uniq
    end
  end
end
