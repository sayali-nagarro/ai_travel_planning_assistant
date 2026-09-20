require "rails_helper"

RSpec.describe Message, type: :model do
  it "belongs to a conversation" do
    conversation = Conversation.create!
    message = described_class.create!(conversation:, role: :user, content: "Hello")

    expect(message.conversation).to eq(conversation)
  end

  it "validates content presence" do
    conversation = Conversation.create!
    message = described_class.new(conversation:, role: :user, content: "")

    expect(message).not_to be_valid
  end

  it "accepts the assistant role" do
    conversation = Conversation.create!
    message = described_class.create!(conversation:, role: :assistant, content: "Answer")

    expect(message.assistant?).to be(true)
  end
end
