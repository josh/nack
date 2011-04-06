begin
  # Avoid activating json gem
  if defined? gem_original_require
    gem_original_require 'json'
  else
    require 'json'
  end
rescue LoadError
end

module Nack
  module JSON
    if defined? ::JSON
      def self.encode(obj)
        obj.to_json
      end

      def self.decode(json)
        ::JSON.parse(json)
      end
    else
      require 'okjson'

      def self.encode(obj)
        ::OkJson.encode(obj)
      end

      def self.decode(json)
        ::OkJson.decode(json)
      end
    end
  end
end
