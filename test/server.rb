require 'nack'

app = lambda do |env|
  [200, {"Content-Type" => "text/plain"}, ["Hello ", "World\n"]]
end

sock = File.expand_path("../nack.sock", __FILE__)

Nack::Server.run(app, sock)
