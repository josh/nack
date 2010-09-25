require 'rack'
require 'socket'
require 'stringio'
require 'thread'
require 'yajl'
require 'nack/error'

module Nack
  class Server
    CRLF = "\r\n"

    SERVER_ERROR = [500, { "Content-Type" => "text/html" }, ["Internal Server Error"]]

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

    def quit!
      self.state = :quit
      server.close
      nil
    end

    def accept?
      state == :ready && !server.closed?
    end

    def on_shutdown(&block)
      if block_given?
        @on_shutdown = block
      else
        @on_shutdown
      end
    end

    def server
      @_server ||= open_server
    end

    def start_server!
      server
    end

    def open_server
      server = if file
        File.unlink(file) if File.exist?(file)

        on_shutdown do
          File.unlink(file)
        end

        UNIXServer.open(file)
      elsif port
        TCPServer.open(port)
      else
        raise Error, "no socket given"
      end

      ready!

      server
    end

    def install_handlers!
      trap('TERM') { shutdown! }
      trap('INT')  { shutdown! }
      trap('QUIT') { quit! }
    end

    def accept!
      if accept?
        server.accept
      else
        shutdown!
      end
    rescue Errno::EBADF
      shutdown!
    rescue Exception => e
      warn "#{e.class}: #{e.message}"
      warn e.backtrace.join("\n")
      shutdown!
    end

    def start
      start_server!
      install_handlers!

      loop do
        debug "Waiting for connection"
        handle accept!
      end

      nil
    end

    def shutdown!
      on_shutdown.call if on_shutdown
      exit! 0
    end

    def handle(sock)
      debug "Accepted connection"

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

      debug "Received request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"

      env = env.merge({
        "rack.version" => Rack::VERSION,
        "rack.input" => input,
        "rack.errors" => $stderr,
        "rack.multithread" => false,
        "rack.multiprocess" => true,
        "rack.run_once" => false,
        "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
      })

      thread = Thread.new do
        begin
          app.call(env)
        rescue Exception => e
          warn "#{e.class}: #{e.message}"
          warn e.backtrace.join("\n")
          SERVER_ERROR
        end
      end
      thread.join
      status, headers, body = thread.value

      debug "Sending response: #{status}"

      encoder = Yajl::Encoder.new

      encoder.encode(status.to_s, sock)
      sock.write(CRLF)

      header = {}
      headers.each do |k, vs|
        vs = vs.split("\n")
        if vs.length == 1
          header[k] = vs[0]
        else
          header[k] = vs
        end
      end

      encoder.encode(header, sock)
      sock.write(CRLF)

      body.each do |part|
        encoder.encode(part, sock)
        sock.write(CRLF)
      end
    rescue Exception => e
      warn "#{e.class}: #{e.message}"
      warn e.backtrace.join("\n")
    ensure
      sock.close_write
    end

    def debug(msg)
      warn msg if $DEBUG
    end
  end
end
