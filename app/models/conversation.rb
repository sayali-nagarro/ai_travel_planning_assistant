class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  before_validation :ensure_preferences

  def preferences
    deserialize_hash_field(:preferences)
  end

  def preferences=(value)
    self[:preferences] = value.to_h.deep_stringify_keys.to_json
  end

  def merge_preferences!(new_preferences)
    update!(preferences: preferences.deep_stringify_keys.deep_merge(new_preferences.to_h.deep_stringify_keys))
  end

  private

  def ensure_preferences
    self[:preferences] = JSON.generate({}) if read_attribute_before_type_cast(:preferences).nil?
  end

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
