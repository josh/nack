require 'json'

module Nack
  module JSON
    def self.encode(obj)
      ::JSON.generate(obj)
    end

    def self.decode(json)
      ::JSON.parse(json)
    end
  end
end
