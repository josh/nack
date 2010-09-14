require 'rack'
require 'socket'
require 'stringio'
require 'yajl'

module Nack
  class Server
    def self.run(*args)
      new(*args).start
    end

    attr_accessor :app, :path

    def initialize(app, path)
      self.app  = app
      self.path = path
    end

    def start
      server = UNIXServer.open(path)

      loop do
        sock = server.accept

        env, input = nil, StringIO.new
        Yajl::Parser.parse(sock) do |obj|
          if env.nil?
            env = obj
          else
            input.write(obj)
          end
        end

        sock.close_read
        input.rewind

        env = env.merge({
          "rack.version" => Rack::VERSION,
          "rack.input" => input,
          "rack.errors" => $stderr,
          "rack.multithread" => false,
          "rack.multiprocess" => true,
          "rack.run_once" => false,
        })

        body = ""
        status, headers, body = app.call(env)

        encoder = Yajl::Encoder.new
        encoder.encode(status.to_s, sock)
        encoder.encode(headers, sock)
        body.each { |part| encoder.encode(part, sock) }

        sock.close_write
      end

      nil
    end
  end
end
