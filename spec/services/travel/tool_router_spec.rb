require "rails_helper"

RSpec.describe Travel::ToolRouter do
  subject(:router) { described_class.new }

  it "selects knowledge for destination questions" do
    decision = router.call(user_message: "What are the best neighbourhoods in Singapore?", context: { destination: "Singapore" })

    expect(decision.needs_knowledge).to be(true)
    expect(decision.needs_weather).to be(false)
    expect(decision.needs_currency).to be(false)
  end

  it "selects weather for forecast questions" do
    decision = router.call(user_message: "What is the weather forecast next week?", context: { destination: "Singapore" })

    expect(decision.needs_weather).to be(true)
    expect(decision.needs_knowledge).to be(false)
  end

  it "keeps indoor or outdoor activity questions on the knowledge path" do
    decision = router.call(user_message: "Should I plan indoor or outdoor activities tomorrow?", context: { destination: "Singapore" })

    expect(decision.needs_knowledge).to be(true)
    expect(decision.needs_weather).to be(false)
    expect(decision.needs_currency).to be(false)
  end

  it "selects currency for conversion questions" do
    decision = router.call(user_message: "Convert INR 50,000 to SGD.", context: { destination: "Singapore" })

    expect(decision.needs_currency).to be(true)
    expect(decision.needs_knowledge).to be(false)
  end

  it "selects currency for name-based conversion questions" do
    decision = router.call(user_message: "110 Indian Rupees to Australian currency", context: { destination: "Singapore" })

    expect(decision.needs_currency).to be(true)
    expect(decision.needs_knowledge).to be(false)
  end

  it "selects combined tools for weather-aware itineraries" do
    decision = router.call(user_message: "Plan three days and adjust it for rain.", context: { destination: "Singapore" })

    expect(decision.needs_knowledge).to be(true)
    expect(decision.needs_weather).to be(true)
    expect(decision.needs_currency).to be(false)
  end
end
