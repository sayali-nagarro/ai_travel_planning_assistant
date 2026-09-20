require "rails_helper"

RSpec.describe Travel::Assistant do
  it "orchestrates knowledge and weather for the primary itinerary scenario" do
    conversation = Conversation.create!

    source = KnowledgeSource.new(title: "Visit Singapore - Things to Do", url: "https://www.visitsingapore.com/en/see-do/", destination: "Singapore", source_type: "tourism_board", metadata: { extracted_topics: [ "attractions", "family", "indoor", "outdoor" ] })
    chunk = KnowledgeChunk.new(knowledge_source: source, chunk_index: 0, content: "Indoor and outdoor highlights for Singapore", embedding: Array.new(32, 0.1), metadata: {})
    hit = Struct.new(:chunk, :source, :score, keyword_init: true).new(chunk: chunk, source: source, score: 0.9)

    retriever = instance_double(Knowledge::Retriever)
    weather_client = instance_double(Mcp::WeatherClient)
    currency_client = instance_double(Mcp::CurrencyClient)
    llm_client = instance_double(Ai::LocalClient)

    expect(retriever).to receive(:call).with(query: /three-day Singapore itinerary/i, destination: "Singapore", top_k: 5).and_return([ hit ])
    expect(weather_client).to receive(:forecast).with(location: "Singapore", days: 3).and_return(
      status: :success,
      data: {
        location: "Singapore",
        forecast: [
          { date: "2026-09-20", temperature_max_c: 32, temperature_min_c: 26, precipitation_probability: 70, condition: "rain" }
        ]
      },
      transport: :mcp
    )
    expect(currency_client).not_to receive(:convert)
    expect(llm_client).to receive(:generate) do |args|
      expect(args[:retrieved_documents].first[:title]).to eq("Visit Singapore - Things to Do")
      expect(args[:tool_results].first[:name]).to eq("weather")

      "Day 1\n- Indoor backup because of rain."
    end

    result = described_class.new(
      conversation:,
      user_message: "Create a three-day Singapore itinerary for next week and adjust it according to the weather forecast.",
      llm_client:,
      retriever:,
      weather_client:,
      currency_client:,
      tool_router: Travel::ToolRouter.new,
      context_builder: Travel::ConversationContext.new,
      prompt_builder: Travel::PromptBuilder.new
    ).call

    expect(result.answer).to include("Day 1")
    expect(result.sources.first[:title]).to eq("Visit Singapore - Things to Do")
    expect(result.tools.first[:name]).to eq("weather")
    expect(conversation.reload.messages.pluck(:role)).to eq([ "user", "assistant" ])
    expect(conversation.preferences["previous_itinerary"]).to include("Day 1")
  end

  it "handles LLM failures safely without losing conversation state" do
    conversation = Conversation.create!
    llm_client = instance_double(Ai::LocalClient)
    allow(llm_client).to receive(:generate).and_raise(StandardError, "LLM unavailable")

    result = described_class.new(
      conversation:,
      user_message: "What are the best neighbourhoods in Singapore?",
      llm_client:,
      retriever: instance_double(Knowledge::Retriever, call: []),
      weather_client: instance_double(Mcp::WeatherClient, forecast: { status: :error, error: "not used" }),
      currency_client: instance_double(Mcp::CurrencyClient, convert: { status: :error, error: "not used" }),
      tool_router: Travel::ToolRouter.new,
      context_builder: Travel::ConversationContext.new,
      prompt_builder: Travel::PromptBuilder.new
    ).call

    expect(result.error).to eq("LLM unavailable")
    expect(conversation.reload.messages.count).to eq(2)
    expect(conversation.messages.last.content).to include("could not complete")
  end

  it "converts currency into the requested target currency" do
    conversation = Conversation.create!
    currency_client = instance_double(Mcp::CurrencyClient)
    llm_client = instance_double(Ai::LocalClient)

    expect(currency_client).to receive(:convert).with(amount: 2.0, from: "AUD", to: "INR").and_return(
      status: :success,
      data: { amount: 2.0, from: "AUD", to: "INR", converted_amount: 110.0, rate: 55.0 },
      transport: :local_rate
    )
    allow(llm_client).to receive(:generate).and_return("2 AUD = 110 INR")

    result = described_class.new(
      conversation:,
      user_message: "Convert AUD 2 to INR.",
      llm_client:,
      retriever: instance_double(Knowledge::Retriever, call: []),
      weather_client: instance_double(Mcp::WeatherClient, forecast: { status: :error, error: "not used" }),
      currency_client:,
      tool_router: Travel::ToolRouter.new,
      context_builder: Travel::ConversationContext.new,
      prompt_builder: Travel::PromptBuilder.new
    ).call

    expect(result.tools.first[:name]).to eq("currency")
    expect(result.tools.first[:data][:to]).to eq("INR")
  end
end
