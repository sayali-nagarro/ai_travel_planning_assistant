class KnowledgeSource < ApplicationRecord
  has_many :knowledge_chunks, dependent: :destroy

  def metadata
    deserialize_hash_field(:metadata)
  end

  def metadata=(value)
    self[:metadata] = value.to_json
  end

  validates :title, :url, :destination, :source_type, presence: true

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
