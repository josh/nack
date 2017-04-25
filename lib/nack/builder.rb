require 'forwardable'

require 'nack/isolated'

module Nack
  class Builder
    extend Forwardable

    def initialize(&block)
      _add_proxy_methods
      instance_eval(&block) if block_given?
    end

    # Add delegators for Rack DSL methods, sending directly to _builder retval.
    def _add_proxy_methods
      _builder_methods.each do |methname|
        metaclass = class << self ; self ; end
        metaclass.send :def_delegator, :_builder, methname
      end
    end

    def _builder_methods
      @builder_methods ||= Nack::Isolated.eval {
        _builder.class.instance_methods(false)
      }
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
  end
end
