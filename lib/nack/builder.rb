module Nack
  class Builder
    def initialize(&block)
      instance_eval(&block) if block_given?
    end

    def _builder
      require 'rack/builder'
      @_builder ||= Rack::Builder.new
    end

    def method_missing(*args, &block)
      _builder.send(*args, &block)
    end
  end
end
