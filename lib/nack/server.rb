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

    attr_accessor :state, :app, :host, :port, :file, :onready

    def initialize(app, options = {})
      self.state  = :starting
      self.app    = app

      self.host = options[:host]
      self.port = options[:port]

      self.file = options[:file]

      self.onready = options[:onready]
    end

    def ready!
      self.state = :ready
      onready.call if onready
      nil
    end

    def server
       @_server ||= open_server
     end

    def open_server
      server = if file
        File.unlink(file) if File.exist?(file)

        at_exit do
          File.unlink(file)
        end

        UNIXServer.open(file)
      elsif port
        TCPServer.open(port)
      else
        raise "no socket given"
      end

      ready!

      server
    end

    def start
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
          "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
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
