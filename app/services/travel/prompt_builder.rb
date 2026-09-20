module Travel
  class PromptBuilder
    def call(context:, retrieved_documents:, tool_results:, conversation_history:, user_message:)
      {
        system_prompt: system_prompt,
        user_prompt: user_prompt(context:, retrieved_documents:, tool_results:, conversation_history:, user_message:)
      }
    end

    private

    def system_prompt
      <<~PROMPT
        You are a production travel planning assistant for Singapore.

        Rules:
        - Use retrieved knowledge base content for destination facts.
        - Do not invent attractions, neighborhoods, transport details, cultural guidance, weather, or exchange rates.
        - Treat Weather MCP and Currency MCP as current information sources when available.
        - If a tool fails, say so clearly and continue with the safe parts of the answer.
        - Distinguish knowledge-base facts, current tool data, and AI recommendations.
        - When asked for an itinerary, use a clear day-by-day structure.
        - Surface source titles and URLs from the knowledge base.
        - Keep recommendations grounded in the retrieved Singapore sources and the user's preferences.
      PROMPT
    end

    def user_prompt(context:, retrieved_documents:, tool_results:, conversation_history:, user_message:)
      lines = []
      lines << "User request: #{user_message}"
      lines << "Context: #{context.compact}"
      lines << "Retrieved documents:"
      retrieved_documents.each do |document|
        lines << "- #{document[:title]} (#{document[:url]}): #{document[:summary]}"
      end
      lines << "Tool results: #{tool_results}"
      lines << "Recent conversation:"
      conversation_history.each do |message|
        lines << "- #{message.role}: #{message.content}"
      end
      lines.join("\n")
    end
  end
end
