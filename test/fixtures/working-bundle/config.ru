require 'bundler/setup'

run lambda { |env|
  [200, {"Content-Type" => "text/plain"}, ["OK"]]
}
