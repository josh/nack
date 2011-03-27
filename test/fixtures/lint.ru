require 'rubygems'

require 'rack/lint'
use Rack::Lint

run lambda { |env|
  [200, {"Content-Type" => "text/plain", "Content-Length" => "2"}, ["OK"]]
}
