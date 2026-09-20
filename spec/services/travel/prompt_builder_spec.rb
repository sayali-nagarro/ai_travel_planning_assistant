require "rails_helper"

RSpec.describe Travel::PromptBuilder do
  describe "#call" do
    it "includes grounding rules and source instructions in the system prompt" do
      result = described_class.new.call(
        context: { destination: "Singapore" },
        retrieved_documents: [
          { title: "Visit Singapore - Things to Do", url: "https://www.visitsingapore.com/en/see-do/", summary: "Attractions and family activities" }
        ],
        tool_results: [],
        conversation_history: [],
        user_message: "What are the must-visit attractions in Singapore?"
      )

      expect(result[:system_prompt]).to include("Use retrieved knowledge base content for destination facts")
      expect(result[:system_prompt]).to include("Do not invent attractions, neighborhoods, transport details, cultural guidance, weather, or exchange rates")
      expect(result[:system_prompt]).to include("Surface source titles and URLs from the knowledge base")
      expect(result[:system_prompt]).to include("Keep recommendations grounded in the retrieved Singapore sources and the user's preferences")
      expect(result[:system_prompt]).to include("For combined requests, separate knowledge-base facts, MCP-provided current information, and recommendations into clearly labeled sections")
    end

    it "renders retrieved sources, tool results, and conversation context into the user prompt" do
      result = described_class.new.call(
        context: { destination: "Singapore", interests: [ "family" ] },
        retrieved_documents: [
          { title: "Visit Singapore - Travel Planning and Itineraries", url: "https://www.visitsingapore.com/en/plan-your-trip/itineraries/", summary: "Three-day itinerary ideas" }
        ],
        tool_results: [ { name: "weather", status: :success, data: { location: "Singapore" } } ],
        conversation_history: [ Struct.new(:role, :content).new("user", "Plan a three-day trip") ],
        user_message: "Plan a three-day trip to Singapore"
      )

      expect(result[:user_prompt]).to include("User request: Plan a three-day trip to Singapore")
      expect(result[:user_prompt]).to include("Context: {destination: \"Singapore\", interests: [\"family\"]}")
      expect(result[:user_prompt]).to include("Visit Singapore - Travel Planning and Itineraries (https://www.visitsingapore.com/en/plan-your-trip/itineraries/): Three-day itinerary ideas")
      expect(result[:user_prompt]).to include("Tool results: [{name: \"weather\", status: :success, data: {location: \"Singapore\"}}]")
      expect(result[:user_prompt]).to include("- user: Plan a three-day trip")
    end
  end
end
