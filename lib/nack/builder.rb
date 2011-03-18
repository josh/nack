module Nack
  class Builder
    def initialize(&block)
      instance_eval(&block) if block_given?
    end

    def _builder
      @_builder ||= begin
        require 'rack'
        require 'rack/builder'
        Rack::Builder.new
      rescue LoadError
        require 'rubygems'
        require 'rack'
        require 'rack/builder'
        Rack::Builder.new
      end
    end

    def method_missing(*args, &block)
      _builder.send(*args, &block)
    end
  end
end
