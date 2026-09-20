class Message < ApplicationRecord
  belongs_to :conversation

  def metadata
    deserialize_hash_field(:metadata)
  end

  def metadata=(value)
    self[:metadata] = value.to_json
  end

  enum :role, {
    system: "system",
    user: "user",
    assistant: "assistant",
    tool: "tool"
  }

  validates :content, presence: true
  validates :role, presence: true

  scope :chronological, -> { order(:created_at, :id) }

  private

  def deserialize_hash_field(attribute_name)
    raw_value = self[attribute_name]
    case raw_value
    when nil
      {}
    when String
      raw_value.empty? ? {} : JSON.parse(raw_value)
    when Hash
      raw_value
    else
      raw_value.to_h
    end
  rescue JSON::ParserError
    {}
  end
end
