require "rails_helper"

RSpec.describe Mcp::WeatherClient do
  it "normalizes a successful transport response" do
    transport = instance_double("Transport")
    allow(transport).to receive(:call).and_return(
      status: :success,
      data: {
        forecast: [
          { date: "2026-09-20", temperature_max_c: 32, temperature_min_c: 26, precipitation_probability: 70, condition: "rain" }
        ]
      }
    )

    result = described_class.new(transport:).forecast(location: "Singapore", days: 1)

    expect(result[:status]).to eq(:success)
    expect(result[:transport]).to eq(:mcp)
    expect(result[:data][:forecast].first[:condition]).to eq("rain")
  end

  it "falls back when the transport fails" do
    client = described_class.new(transport: instance_double("Transport", call: { status: :error, error: "boom" }))
    allow(client).to receive(:fallback_weather).and_return(status: :success, data: { location: "Singapore", forecast: [] }, transport: :open_meteo)

    result = client.forecast(location: "Singapore", days: 1)

    expect(result[:status]).to eq(:success)
    expect(result[:transport]).to eq(:open_meteo)
  end
end
