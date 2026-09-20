require "json"
require "net/http"
require "uri"

module Mcp
  class WeatherClient
    DEFAULT_COORDINATES = { latitude: 1.3521, longitude: 103.8198 }.freeze

    def initialize(transport: nil, timeout: 10)
      @transport = transport || build_transport(timeout)
    end

    def forecast(location: "Singapore", days: 3)
      response = transport.call(method: "weather.forecast", params: { location: location, days: days })
      return normalize_transport_response(response, location) if response[:status] == :success

      fallback_weather(location:, days:)
    end

    private

    attr_reader :transport

    def build_transport(timeout)
      endpoint = ENV["WEATHER_MCP_URL"]
      return LocalWeatherTransport.new(timeout:) unless endpoint.present?

      JsonRpcClient.new(endpoint:, timeout:)
    end

    def normalize_transport_response(response, location)
      data = response[:data] || response["data"] || response
      { status: :success, data: normalize_forecast(data, location), transport: :mcp }
    end

    def fallback_weather(location:, days:)
      uri = URI.parse("https://api.open-meteo.com/v1/forecast?latitude=#{DEFAULT_COORDINATES[:latitude]}&longitude=#{DEFAULT_COORDINATES[:longitude]}&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code&forecast_days=#{days}&timezone=Asia/Singapore")
      response = Net::HTTP.get_response(uri)
      payload = JSON.parse(response.body)

      { status: :success, data: normalize_forecast(payload, location), transport: :open_meteo }
    rescue StandardError => e
      { status: :error, error: e.message }
    end

    def normalize_forecast(payload, location)
      if payload.is_a?(Hash) && (payload["forecast"].is_a?(Array) || payload[:forecast].is_a?(Array))
        forecast_rows = payload["forecast"] || payload[:forecast]
        return {
          location: payload["location"] || payload[:location] || location,
          forecast: forecast_rows.map do |entry|
            entry.transform_keys(&:to_sym)
          end
        }
      end

      daily = payload["daily"] || payload[:daily] || {}
      dates = daily["time"] || daily[:time] || []
      temperatures_max = daily["temperature_2m_max"] || daily[:temperature_2m_max] || []
      temperatures_min = daily["temperature_2m_min"] || daily[:temperature_2m_min] || []
      precipitation = daily["precipitation_probability_max"] || daily[:precipitation_probability_max] || []
      weather_codes = daily["weather_code"] || daily[:weather_code] || []

      {
        location: location,
        forecast: dates.each_index.map do |index|
          {
            date: dates[index],
            temperature_max_c: temperatures_max[index],
            temperature_min_c: temperatures_min[index],
            precipitation_probability: precipitation[index],
            condition: weather_condition(weather_codes[index])
          }
        end
      }
    end

    def weather_condition(code)
      case code.to_i
      when 0 then "clear"
      when 1, 2 then "partly_cloudy"
      when 3 then "cloudy"
      when 45, 48 then "fog"
      when 51, 53, 55, 61, 63, 65, 80, 81, 82 then "rain"
      when 71, 73, 75, 77, 85, 86 then "snow"
      when 95, 96, 99 then "storm"
      else "unknown"
      end
    end

    class LocalWeatherTransport
      def initialize(timeout:)
        @timeout = timeout
      end

      def call(method:, params:)
        endpoint = ENV["WEATHER_MCP_URL"]
        return { status: :error, error: "No MCP endpoint configured" } unless endpoint.present?

        JsonRpcClient.new(endpoint:, timeout: timeout).call(method:, params:)
      end

      private

      attr_reader :timeout
    end
  end
end
