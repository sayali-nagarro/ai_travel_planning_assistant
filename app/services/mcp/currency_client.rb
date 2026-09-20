require "json"
require "net/http"
require "uri"

module Mcp
  class CurrencyClient
    def initialize(transport: nil, timeout: 10)
      @transport = transport || build_transport(timeout)
    end

    def convert(amount:, from:, to:)
      response = transport.call(method: "currency.convert", params: { amount: amount, from: from, to: to })
      return normalize_transport_response(response, amount:, from:, to:) if response[:status] == :success

      fallback_conversion(amount:, from:, to:)
    end

    private

    attr_reader :transport

    def build_transport(timeout)
      endpoint = ENV["CURRENCY_MCP_URL"]
      return LocalCurrencyTransport.new(timeout:) unless endpoint.present?

      JsonRpcClient.new(endpoint:, timeout:)
    end

    def normalize_transport_response(response, amount:, from:, to:)
      data = response[:data] || response["data"] || response
      { status: :success, data: normalize_conversion(data, amount:, from:, to:), transport: :mcp }
    end

    def fallback_conversion(amount:, from:, to:)
      uri = URI.parse("https://api.frankfurter.app/latest?amount=#{amount}&from=#{from}&to=#{to}")
      response = Net::HTTP.get_response(uri)
      payload = JSON.parse(response.body)

      { status: :success, data: normalize_conversion(payload, amount:, from:, to:), transport: :frankfurter }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    def normalize_conversion(payload, amount:, from:, to:)
      rates = payload["rates"] || payload[:rates] || {}
      converted = rates[to] || rates[to.to_sym]

      {
        amount: amount,
        from: from,
        to: to,
        converted_amount: converted,
        rate: converted.to_f / amount.to_f
      }
    end

    class LocalCurrencyTransport
      def initialize(timeout:)
        @timeout = timeout
      end

      def call(method:, params:)
        endpoint = ENV["CURRENCY_MCP_URL"]
        return { status: :error, error: "No MCP endpoint configured" } unless endpoint.present?

        JsonRpcClient.new(endpoint:, timeout: timeout).call(method:, params:)
      end

      private

      attr_reader :timeout
    end
  end
end
