module Nack
  class Builder
    def initialize(&block)
      setup_bundler if setup_bundler?
      
      instance_eval(&block) if block_given?
    end
    
    def setup_bundler?
      begin
        require 'bundler/shared_helpers'
      rescue LoadError
        begin
          require 'rubygems'
          require 'bundler/shared_helpers'
        rescue LoadError
        end
      end

      defined? Bundler and Bundler::SharedHelpers.in_bundle?
    end

    def setup_bundler
      # Make sure builder is constructed before we bundle so rack
      # can still be loaded
      _builder
      
      require 'bundler'
      Bundler.setup

      # Add bundler to the load path after disabling system gems
      bundler_lib = File.expand_path("../..", __FILE__)
      $LOAD_PATH.unshift(bundler_lib) unless $LOAD_PATH.include?(bundler_lib)
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
