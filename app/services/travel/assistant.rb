module Travel
  Result = Struct.new(:answer, :sources, :tools, :assistant_message, :conversation, :retrieved_documents, :context, :error, keyword_init: true) do
    def as_json(*)
      {
        answer: answer,
        sources: sources,
        tools: tools,
        error: error,
        conversation_id: conversation&.id,
        message_id: assistant_message&.id,
        retrieved_documents: retrieved_documents,
        context: context
      }
    end
  end

  class Assistant
    def self.call(conversation:, user_message:, llm_client: Ai::LlmClient.build, retriever: Knowledge::Retriever.new, weather_client: Mcp::WeatherClient.new, currency_client: Mcp::CurrencyClient.new, tool_router: Travel::ToolRouter.new, context_builder: Travel::ConversationContext.new, prompt_builder: Travel::PromptBuilder.new)
      new(
        conversation:,
        user_message:,
        llm_client:,
        retriever:,
        weather_client:,
        currency_client:,
        tool_router:,
        context_builder:,
        prompt_builder:
      ).call
    end

    def initialize(conversation:, user_message:, llm_client:, retriever:, weather_client:, currency_client:, tool_router:, context_builder:, prompt_builder:)
      @conversation = conversation
      @user_message = user_message
      @llm_client = llm_client
      @retriever = retriever
      @weather_client = weather_client
      @currency_client = currency_client
      @tool_router = tool_router
      @context_builder = context_builder
      @prompt_builder = prompt_builder
    end

    def call
      user_record = conversation.messages.create!(role: :user, content: user_message, metadata: { kind: "user_request" })
      context = context_builder.build(conversation:, user_message:)
      decision = tool_router.call(user_message:, context:)

      retrieved_documents = []
      if decision.needs_knowledge
        retrieved_documents = retriever.call(query: user_message, destination: context[:destination], top_k: 5).map { |hit| format_document(hit) }
      end

      tool_results = []
      if decision.needs_weather
        tool_results << build_tool_result(:weather, weather_client.forecast(location: context[:destination], days: 3))
      end

      if decision.needs_currency && (budget = context[:budget]).present? && (from = context[:budget_currency]).present?
        to = context[:target_currency].presence || "SGD"
        tool_results << build_tool_result(:currency, currency_client.convert(amount: budget, from: from, to: to))
      elsif decision.needs_currency
        tool_results << { name: "currency", status: :error, error: "No budget currency was provided." }
      end

      prompt = prompt_builder.call(
        context: context,
        retrieved_documents: retrieved_documents,
        tool_results: tool_results,
        conversation_history: conversation.messages.chronological.last(8),
        user_message: user_message
      )

      answer = llm_client.generate(
        messages: conversation.messages.chronological.last(8),
        system_prompt: prompt[:system_prompt],
        context: context,
        retrieved_documents: retrieved_documents,
        tool_results: tool_results
      )

      assistant_message = conversation.messages.create!(
        role: :assistant,
        content: answer,
        metadata: {
          source_count: retrieved_documents.size,
          sources: retrieved_documents.map { |document| document.slice(:title, :url, :source_type) },
          tools: tool_results,
          decision: decision.reason,
          request_kind: request_kind(tool_results:, retrieved_documents:, decision: decision)
        }
      )

      context_builder.persist!(conversation:, user_message:, assistant_response: { itinerary_summary: answer.truncate(280) })

      Result.new(
        answer: answer,
        sources: retrieved_documents.map { |document| document.slice(:title, :url, :source_type) },
        tools: tool_results,
        assistant_message: assistant_message,
        conversation: conversation,
        retrieved_documents: retrieved_documents,
        context: context,
        error: nil
      )
    rescue StandardError => e
      fallback_answer = "I could not complete the request safely because #{e.message}."
      assistant_message = conversation.messages.create!(role: :assistant, content: fallback_answer, metadata: { status: "error", error: e.message })

      Result.new(
        answer: fallback_answer,
        sources: [],
        tools: [],
        assistant_message: assistant_message,
        conversation: conversation,
        retrieved_documents: [],
        context: {},
        error: e.message
      )
    end

    private

    attr_reader :conversation, :user_message, :llm_client, :retriever, :weather_client, :currency_client, :tool_router, :context_builder, :prompt_builder

    def format_document(hit)
      {
        title: hit.source.title,
        url: hit.source.url,
        source_type: hit.source.source_type,
        summary: hit.chunk.content.split("\n\n").last.to_s,
        content: hit.chunk.content,
        tags: Array(hit.source.metadata["extracted_topics"] || hit.source.metadata[:extracted_topics])
      }
    end

    def build_tool_result(name, response)
      if response[:status] == :success
        { name: name.to_s, status: :success, data: response[:data], transport: response[:transport] }
      else
        { name: name.to_s, status: :error, error: response[:error] }
      end
    end

    def request_kind(tool_results:, retrieved_documents:, decision:)
      return "combined" if decision.needs_weather && decision.needs_currency
      return "weather" if decision.needs_weather && !decision.needs_currency
      return "currency" if decision.needs_currency && !decision.needs_weather
      return "knowledge" if retrieved_documents.any?

      tool_results.any? ? "tool_only" : "other"
    end
  end
end
