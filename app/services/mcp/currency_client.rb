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
      conversion = normalize_conversion(payload, amount:, from:, to:)

      if conversion[:converted_amount].present?
        { status: :success, data: conversion, transport: :frankfurter }
      else
        local_conversion(amount:, from:, to:, error: "Frankfurter response did not include a usable rate.")
      end
    rescue StandardError => e
      local_conversion(amount:, from:, to:, error: e.message)
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

    def local_conversion(amount:, from:, to:, error:)
      rate = local_rate(from:, to:)
      return { status: :error, error: error } unless rate

      converted_amount = amount.to_f * rate

      {
        status: :success,
        data: {
          amount: amount,
          from: from,
          to: to,
          converted_amount: converted_amount,
          rate: rate
        },
        transport: :local_rate
      }
    end

    def local_rate(from:, to:)
      source_rate = local_rate_table[from.to_s.upcase]
      target_rate = local_rate_table[to.to_s.upcase]
      return 1.0 if from.to_s.upcase == to.to_s.upcase
      return nil unless source_rate && target_rate

      source_rate.to_f / target_rate.to_f
    end

    def local_rate_table
      {
        "INR" => 1.0,
        "AUD" => 55.0,
        "SGD" => 60.6060606061,
        "USD" => 83.0,
        "EUR" => 90.0,
        "GBP" => 105.0,
        "JPY" => 0.6
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
