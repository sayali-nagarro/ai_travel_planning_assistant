require "json"

module HashTextCoder
  def self.dump(value)
    return if value.nil?

    JSON.generate(value)
  end

  def self.load(value)
    case value
    when nil
      {}
    when String
      value.empty? ? {} : JSON.parse(value)
    when Hash
      value
    else
      value.to_h
    end
  rescue JSON::ParserError
    {}
  end
end
