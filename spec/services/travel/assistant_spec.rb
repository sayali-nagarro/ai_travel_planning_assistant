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

  it "combines knowledge and currency for a budget-aware itinerary request" do
    conversation = Conversation.create!

    source = KnowledgeSource.new(title: "Visit Singapore - Travel Planning and Itineraries", url: "https://www.visitsingapore.com/en/plan-your-trip/itineraries/", destination: "Singapore", source_type: "tourism_board", metadata: { extracted_topics: [ "itinerary", "transport", "family" ] })
    chunk = KnowledgeChunk.new(knowledge_source: source, chunk_index: 0, content: "Three-day itinerary ideas with MRT guidance and family-friendly stops", embedding: Array.new(32, 0.1), metadata: {})
    hit = Struct.new(:chunk, :source, :score, keyword_init: true).new(chunk: chunk, source: source, score: 0.9)

    retriever = instance_double(Knowledge::Retriever)
    currency_client = instance_double(Mcp::CurrencyClient)
    weather_client = instance_double(Mcp::WeatherClient)
    llm_client = instance_double(Ai::LocalClient)

    expect(retriever).to receive(:call).with(query: /budget of INR 60,000.*three-day itinerary/i, destination: "Singapore", top_k: 5).and_return([ hit ])
    expect(currency_client).to receive(:convert).with(amount: 60_000.0, from: "INR", to: "SGD").and_return(
      status: :success,
      data: { amount: 60_000.0, from: "INR", to: "SGD", converted_amount: 960.0, rate: 0.016 },
      transport: :local_rate
    )
    expect(weather_client).not_to receive(:forecast)
    expect(llm_client).to receive(:generate) do |args|
      expect(args[:tool_results].first[:name]).to eq("currency")
      "Budget-aware Singapore itinerary"
    end

    result = described_class.new(
      conversation:,
      user_message: "I have a budget of INR 60,000. Convert it to SGD and suggest a three-day itinerary.",
      llm_client:,
      retriever:,
      weather_client:,
      currency_client:,
      tool_router: Travel::ToolRouter.new,
      context_builder: Travel::ConversationContext.new,
      prompt_builder: Travel::PromptBuilder.new
    ).call

    expect(result.tools.first[:name]).to eq("currency")
    expect(result.context[:budget]).to eq(60_000.0)
    expect(result.context[:target_currency]).to eq("SGD")
    expect(result.sources.first[:title]).to eq("Visit Singapore - Travel Planning and Itineraries")
    expect(result.answer).to eq("Budget-aware Singapore itinerary")
  end

  it "handles LLM failures safely without losing conversation state" do
    conversation = Conversation.create!
    llm_client = instance_double(Ai::LocalClient)
    allow(llm_client).to receive(:generate).and_raise(StandardError, "LLM unavailable")

    source = KnowledgeSource.new(title: "Visit Singapore - Things to Do", url: "https://www.visitsingapore.com/en/see-do/", destination: "Singapore", source_type: "tourism_board", metadata: { extracted_topics: [ "attractions" ] })
    chunk = KnowledgeChunk.new(knowledge_source: source, chunk_index: 0, content: "Marina Bay, Gardens by the Bay", embedding: Array.new(32, 0.1), metadata: {})
    hit = Struct.new(:chunk, :source, :score, keyword_init: true).new(chunk: chunk, source: source, score: 0.9)

    result = described_class.new(
      conversation:,
      user_message: "What are the best neighbourhoods in Singapore?",
      llm_client:,
      retriever: instance_double(Knowledge::Retriever, call: [ hit ]),
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

  it "reimports knowledge when the destination knowledge base is empty" do
    conversation = Conversation.create!
    retriever = instance_double(Knowledge::Retriever)
    llm_client = instance_double(Ai::LocalClient)

    expect(retriever).to receive(:call).and_return([]).ordered
    expect(retriever).to receive(:call).and_return([
      hit = Struct.new(:chunk, :source, :score, keyword_init: true).new(
        chunk: KnowledgeChunk.new(
          knowledge_source: KnowledgeSource.new(
            title: "Visit Singapore - Things to Do",
            url: "https://www.visitsingapore.com/en/see-do/",
            destination: "Singapore",
            source_type: "tourism_board",
            metadata: { extracted_topics: [ "attractions" ] }
          ),
          chunk_index: 0,
          content: "Marina Bay, Gardens by the Bay, Singapore Flyer",
          embedding: Array.new(32, 0.1),
          metadata: {}
        ),
        source: KnowledgeSource.new(
          title: "Visit Singapore - Things to Do",
          url: "https://www.visitsingapore.com/en/see-do/",
          destination: "Singapore",
          source_type: "tourism_board",
          metadata: { extracted_topics: [ "attractions" ] }
        ),
        score: 0.9
      )
    ]).ordered

    expect(Knowledge::Importer).to receive(:new).and_call_original
    allow(llm_client).to receive(:generate).and_return("Marina Bay is a must-visit attraction.")

    result = described_class.new(
      conversation:,
      user_message: "What are the must-visit attractions in Singapore?",
      llm_client:,
      retriever:,
      weather_client: instance_double(Mcp::WeatherClient, forecast: { status: :error, error: "not used" }),
      currency_client: instance_double(Mcp::CurrencyClient, convert: { status: :error, error: "not used" }),
      tool_router: Travel::ToolRouter.new,
      context_builder: Travel::ConversationContext.new,
      prompt_builder: Travel::PromptBuilder.new
    ).call

    expect(result.retrieved_documents).not_to be_empty
    expect(result.answer).to include("Marina Bay")
  end

  it "returns a clear safe fallback when destination knowledge is still unavailable" do
    conversation = Conversation.create!
    retriever = instance_double(Knowledge::Retriever)
    llm_client = instance_double(Ai::LocalClient)

    allow(retriever).to receive(:call).and_return([])
    expect(Knowledge::Importer).to receive(:new).and_call_original
    expect(llm_client).not_to receive(:generate)

    result = described_class.new(
      conversation:,
      user_message: "What are the must-visit attractions in Singapore?",
      llm_client:,
      retriever:,
      weather_client: instance_double(Mcp::WeatherClient, forecast: { status: :error, error: "not used" }),
      currency_client: instance_double(Mcp::CurrencyClient, convert: { status: :error, error: "not used" }),
      tool_router: Travel::ToolRouter.new,
      context_builder: Travel::ConversationContext.new,
      prompt_builder: Travel::PromptBuilder.new
    ).call

    expect(result.error).to eq("knowledge_base_empty")
    expect(result.answer).to include("could not retrieve enough destination knowledge")
  end

  it "answers common destination questions from retrieved knowledge" do
    question_cases = [
      [ "What are the must-visit attractions in Singapore?", /attractions/i ],
      [ "Which neighbourhoods are suitable for cultural experiences?", /neighbourhoods|neighborhoods/i ],
      [ "How can a tourist travel around Singapore?", /travel around Singapore/i ],
      [ "Suggest activities for a family with children.", /family with children/i ],
      [ "Create a three-day sightseeing itinerary.", /three-day sightseeing itinerary/i ],
      [ "What indoor attractions can I visit?", /indoor attractions/i ]
    ]

    question_cases.each do |question, expected_query|
      conversation = Conversation.create!
      source = KnowledgeSource.new(title: "Visit Singapore - Things to Do", url: "https://www.visitsingapore.com/en/see-do/", destination: "Singapore", source_type: "tourism_board", metadata: { extracted_topics: [ "attractions", "family", "indoor", "outdoor" ] })
      chunk = KnowledgeChunk.new(knowledge_source: source, chunk_index: 0, content: "Marina Bay, Gardens by the Bay, Chinatown, MRT, family friendly indoor attractions", embedding: Array.new(32, 0.1), metadata: {})
      hit = Struct.new(:chunk, :source, :score, keyword_init: true).new(chunk: chunk, source: source, score: 0.9)
      retriever = instance_double(Knowledge::Retriever)
      llm_client = instance_double(Ai::LocalClient)

      expect(retriever).to receive(:call).with(query: expected_query, destination: "Singapore", top_k: 5).and_return([ hit ])
      allow(llm_client).to receive(:generate).and_return("Grounded Singapore answer")

      result = described_class.new(
        conversation:,
        user_message: question,
        llm_client:,
        retriever:,
        weather_client: instance_double(Mcp::WeatherClient, forecast: { status: :error, error: "not used" }),
        currency_client: instance_double(Mcp::CurrencyClient, convert: { status: :error, error: "not used" }),
        tool_router: Travel::ToolRouter.new,
        context_builder: Travel::ConversationContext.new,
        prompt_builder: Travel::PromptBuilder.new
      ).call

      expect(result.sources.first[:title]).to eq("Visit Singapore - Things to Do")
      expect(result.retrieved_documents.first[:title]).to eq("Visit Singapore - Things to Do")
      expect(result.error).to be_nil
    end
  end
end
