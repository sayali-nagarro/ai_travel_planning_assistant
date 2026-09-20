require "rails_helper"

RSpec.describe Travel::ConversationContext do
  let(:conversation) { Conversation.create! }
  let(:context) { described_class.new }

  it "extracts family, age, duration, and travel window preferences" do
    result = context.build(
      conversation: conversation,
      user_message: "I'm travelling with my wife and 8-year-old son. Plan three days for us next week in Singapore."
    )

    expect(result[:destination]).to eq("Singapore")
    expect(result[:travel_party]).to eq("family")
    expect(result[:party_size]).to eq(3)
    expect(result[:children_ages]).to eq([ 8 ])
    expect(result[:trip_duration_days]).to eq(3)
    expect(result[:travel_window]).to eq("next week")
  end

  it "persists itinerary summaries back into the conversation" do
    context.persist!(conversation:, user_message: "Plan three days in Singapore", assistant_response: { itinerary_summary: "Day 1..." })

    expect(conversation.reload.preferences["previous_itinerary"]).to eq("Day 1...")
  end

  it "overwrites a prior trip duration when the next prompt asks for a different length" do
    context.persist!(conversation:, user_message: "Plan a 2-day Singapore itinerary for a family of 4.")

    result = context.build(
      conversation: conversation,
      user_message: "Plan a 4-day Singapore itinerary for a family of 4 next month."
    )

    expect(result[:trip_duration_days]).to eq(4)
    expect(result[:preferences]["trip_duration_days"]).to eq(4)
  end

  it "treats month-based requests as longer itineraries" do
    result = context.build(
      conversation: conversation,
      user_message: "Plan a 2-month Singapore itinerary for a family of 4 next month."
    )

    expect(result[:trip_duration_days]).to eq(60)
  end

  it "extracts a target currency for conversion requests" do
    result = context.build(
      conversation: conversation,
      user_message: "Convert AUD 2 to INR."
    )

    expect(result[:budget_currency]).to eq("AUD")
    expect(result[:target_currency]).to eq("INR")
  end

  it "extracts budget amounts written before the currency code" do
    result = context.build(
      conversation: conversation,
      user_message: "How much is 2 AUD in INR?"
    )

    expect(result[:budget]).to eq(2.0)
    expect(result[:budget_currency]).to eq("AUD")
    expect(result[:target_currency]).to eq("INR")
  end

  it "understands common currency names for conversion requests" do
    result = context.build(
      conversation: conversation,
      user_message: "110 Indian Rupees to Australian currency"
    )

    expect(result[:budget]).to eq(110.0)
    expect(result[:budget_currency]).to eq("INR")
    expect(result[:target_currency]).to eq("AUD")
  end
end
