require 'rubygems'
require 'rack/file'
run Rack::File.new(File.dirname(__FILE__))
