module Ai
  class LlmClient
    def self.build
      if ENV["LLM_API_KEY"].present?
        OpenAiClient.new
      else
        LocalClient.new
      end
    end
  end
end
