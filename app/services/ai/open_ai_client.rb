require "json"
require "net/http"
require "uri"

module Ai
  class OpenAiClient
    def initialize(api_key: ENV["LLM_API_KEY"], model: ENV.fetch("LLM_MODEL", "gpt-4o-mini"), base_url: ENV.fetch("LLM_BASE_URL", "https://api.openai.com/v1/chat/completions"))
      @api_key = api_key
      @model = model
      @base_url = base_url
    end

    def generate(messages:, system_prompt:, context:, retrieved_documents:, tool_results:)
      payload = {
        model: model,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: build_user_prompt(context:, retrieved_documents:, tool_results:, messages:) }
        ],
        temperature: 0.2
      }

      uri = URI.parse(base_url)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      body = JSON.parse(response.body)
      body.dig("choices", 0, "message", "content").to_s.strip
    end

    private

    attr_reader :api_key, :model, :base_url

    def build_user_prompt(context:, retrieved_documents:, tool_results:, messages:)
      lines = []
      lines << "Context: #{context.compact}"
      lines << "Retrieved documents:"
      retrieved_documents.each do |document|
        lines << "- #{document[:title]}: #{document[:content]}"
      end
      lines << "Tool results: #{tool_results}"
      lines << "Recent messages:"
      messages.last(6).each do |message|
        lines << "- #{message.role}: #{message.content}"
      end
      lines.join("\n")
    end
  end
end
