require "rails_helper"

RSpec.describe Ai::LocalClient do
  describe "#generate" do
    it "adapts the itinerary length to the requested trip duration" do
      client = described_class.new
      message = Struct.new(:content).new("Plan a 2-day Singapore itinerary for a family of 4 next month.")

      result = client.generate(
        messages: [ message ],
        system_prompt: "",
        context: { trip_duration_days: 2, travel_party: "family" },
        retrieved_documents: [],
        tool_results: []
      )

      expect(result).to include("Trip overview: a 2-day Singapore plan for family.")
      expect(result.scan(/^Day \d+/).size).to eq(2)
    end

    it "produces more day sections for longer trips" do
      client = described_class.new
      message = Struct.new(:content).new("Plan a 4-day Singapore itinerary for a family of 4 next month.")

      result = client.generate(
        messages: [ message ],
        system_prompt: "",
        context: { trip_duration_days: 4, travel_party: "family" },
        retrieved_documents: [],
        tool_results: []
      )

      expect(result).to include("Trip overview: a 4-day Singapore plan for family.")
      expect(result.scan(/^Day \d+/).size).to eq(4)
    end

    it "keeps generating one day section per requested day for long trips" do
      client = described_class.new
      message = Struct.new(:content).new("Plan a 12-day Singapore itinerary for a family of 4 next month.")

      result = client.generate(
        messages: [ message ],
        system_prompt: "",
        context: { trip_duration_days: 12, travel_party: "family" },
        retrieved_documents: [],
        tool_results: []
      )

      expect(result).to include("Trip overview: a 12-day Singapore plan for family.")
      expect(result.scan(/^Day \d+/).size).to eq(12)
    end

    it "returns a binary answer for weather-only indoor or outdoor questions" do
      client = described_class.new
      message = Struct.new(:content).new("Should I plan indoor or outdoor activities tomorrow?")

      result = client.generate(
        messages: [ message ],
        system_prompt: "",
        context: {},
        retrieved_documents: [],
        tool_results: [
          {
            name: "weather",
            status: :success,
            data: {
              forecast: [
                { date: "2026-09-20", condition: "rain", precipitation_probability: 30 },
                { date: "2026-09-21", condition: "storm", precipitation_probability: 90 }
              ]
            }
          }
        ]
      )

      expect(result).to start_with("Yes.")
      expect(result).not_to include("Day 1")
    end

    it "separates knowledge, MCP data, and recommendations for combined itinerary and currency requests" do
      client = described_class.new
      message = Struct.new(:content).new("I have a budget of INR 60,000. Convert it to SGD and suggest a three-day itinerary.")

      result = client.generate(
        messages: [ message ],
        system_prompt: "",
        context: { trip_duration_days: 3, travel_party: "family", budget: 60_000, budget_currency: "INR", target_currency: "SGD" },
        retrieved_documents: [
          { title: "Visit Singapore - Travel Planning and Itineraries", summary: "Three-day sightseeing ideas", tags: [ "itinerary" ] }
        ],
        tool_results: [
          {
            name: "currency",
            status: :success,
            data: { amount: 60_000, from: "INR", to: "SGD", converted_amount: 960.0, rate: 0.016 }
          }
        ]
      )

      expect(result).to include("Knowledge-base facts:")
      expect(result).to include("Current information from Currency MCP:")
      expect(result).to include("LLM recommendations:")
      expect(result).to include("Budget context: 60000 INR")
      expect(result).to include("Trip overview: a 3-day Singapore plan for family.")
    end
  end
end
