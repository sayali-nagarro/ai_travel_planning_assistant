require "rails_helper"

RSpec.describe Conversation, type: :model do
  it "defaults preferences to an empty hash" do
    conversation = described_class.new

    expect(conversation.preferences).to eq({})
  end

  it "has many messages" do
    conversation = described_class.create!
    conversation.messages.create!(role: :user, content: "Hello")

    expect(conversation.messages.count).to eq(1)
  end

  it "merges preferences deeply" do
    conversation = described_class.create!(preferences: { "travel_party" => "family", "nested" => { "one" => 1 } })

    conversation.merge_preferences!(travel_party: "couple", nested: { two: 2 })

    expect(conversation.reload.preferences).to include("travel_party" => "couple")
    expect(conversation.preferences["nested"]).to include("one" => 1, "two" => 2)
  end
end
