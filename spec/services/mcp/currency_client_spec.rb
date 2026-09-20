require "rails_helper"

RSpec.describe Mcp::CurrencyClient do
  it "normalizes a successful transport response" do
    transport = instance_double("Transport")
    allow(transport).to receive(:call).and_return(status: :success, data: { rates: { "SGD" => 165.0 } })

    result = described_class.new(transport:).convert(amount: 100, from: "INR", to: "SGD")

    expect(result[:status]).to eq(:success)
    expect(result[:transport]).to eq(:mcp)
    expect(result[:data][:converted_amount]).to eq(165.0)
  end

  it "falls back when the transport fails" do
    client = described_class.new(transport: instance_double("Transport", call: { status: :error, error: "boom" }))
    allow(client).to receive(:fallback_conversion).and_return(status: :success, data: { amount: 100, from: "INR", to: "SGD", converted_amount: 1.65 }, transport: :frankfurter)

    result = client.convert(amount: 100, from: "INR", to: "SGD")

    expect(result[:status]).to eq(:success)
    expect(result[:transport]).to eq(:frankfurter)
  end
end
