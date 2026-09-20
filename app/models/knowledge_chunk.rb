class KnowledgeChunk < ApplicationRecord
  belongs_to :knowledge_source

  def metadata
    deserialize_hash_field(:metadata)
  end

  def metadata=(value)
    self[:metadata] = value.to_json
  end

  validates :content, :chunk_index, :embedding, presence: true

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
