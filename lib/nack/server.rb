require 'rack'
require 'socket'
require 'stringio'
require 'yajl'

module Nack
  class Server
    CRLF = "\r\n"

    def self.run(*args)
      new(*args).start
    end

    attr_accessor :app, :path

    def initialize(app, path)
      self.app  = app
      self.path = path
    end

    def start
      File.unlink(path) if File.exist?(path)
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
        sock.write(CRLF)

        encoder.encode(headers, sock)
        sock.write(CRLF)

        body.each do |part|
          encoder.encode(part, sock)
          sock.write(CRLF)
        end

        sock.close_write
      end

      nil
    end
  end
end
