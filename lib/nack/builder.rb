module Nack
  class Builder
    def initialize(&block)
      _add_builder_proxy_methods
      instance_eval(&block) if block_given?
    end

    # Prevent calls to Rack::Builder methods from interception in outer scopes.
    def _add_builder_proxy_methods
      rack_builder_instance_methods = [:use, :run, :map, :to_app, :call]
      rack_builder_instance_methods.each do |methname|
        metaclass = class << self ; self ; end
        metaclass.send(:define_method, methname) do |*args, &block|
          _builder.send(methname, *args, &block)
        end
      end
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
