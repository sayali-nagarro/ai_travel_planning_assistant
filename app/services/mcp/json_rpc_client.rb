require "json"
require "net/http"
require "uri"
require "securerandom"

module Mcp
  class JsonRpcClient
    def initialize(endpoint:, timeout: 10)
      @endpoint = endpoint
      @timeout = timeout
    end

    def call(method:, params:)
      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        jsonrpc: "2.0",
        id: SecureRandom.uuid,
        method: method,
        params: params
      )

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout, open_timeout: timeout) do |http|
        http.request(request)
      end

      payload = JSON.parse(response.body)
      return { status: :success, data: payload["result"] } if payload["result"]

      { status: :error, error: payload.dig("error", "message") || "MCP request failed" }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    private

    attr_reader :endpoint, :timeout
  end
end
