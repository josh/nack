require 'json'

module Nack
  module JSON
    def self.encode(obj)
      obj.to_json
    end

    def self.decode(json)
      ::JSON.parse(json)
    end
  end
end
