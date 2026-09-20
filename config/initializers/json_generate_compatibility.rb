require "json"
require "active_support/json"

module JSON
  class << self
    unless method_defined?(:generate_without_rails_compatibility)
      alias_method :generate_without_rails_compatibility, :generate

      def generate(value, *args, **kwargs)
        kwargs.delete(:quirks_mode)
        generate_without_rails_compatibility(value, *args, **kwargs)
      end
    end
  end
end

module ActiveSupport
  module JSON
    module Encoding
      class JSONGemEncoder
        def stringify(value)
          ::JSON.generate(value, max_nesting: false)
        end
      end
    end
  end
end
