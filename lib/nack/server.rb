require 'json'
require 'rack'
require 'socket'
require 'stringio'
require 'thread'

require 'nack/error'
require 'nack/netstring'

module Nack
  class Server
    SERVER_ERROR = [500, { "Content-Type" => "text/html" }, ["Internal Server Error"]]

    def self.run(*args)
      new(*args).start
    end

    attr_accessor :state, :app, :host, :port, :file, :onready
    attr_accessor :name, :request_count

    def initialize(app, options = {})
      self.state  = :starting
      self.app    = app

      self.host = options[:host]
      self.port = options[:port]

      self.file = options[:file]

      self.onready = options[:onready]

      self.name = options[:name] || "app"
      self.request_count = 0
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
        $0 = "nackup [#{name}] (#{request_count})"
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
      self.request_count += 1
      debug "Accepted connection"

      env, input = nil, StringIO.new
      NetString.read(sock) do |data|
        if env.nil?
          env = JSON.parse(data)
        elsif data.length > 0
          input.write(data)
        else
          # break
        end
      end

      sock.close_read
      input.rewind

      method, path = env['REQUEST_METHOD'], env['PATH_INFO']
      debug "Received request: #{method} #{path}"
      $0 = "nackup [#{name}] (#{request_count}) #{method} #{path}"

      env = env.merge({
        "rack.version" => Rack::VERSION,
        "rack.input" => input,
        "rack.errors" => $stderr,
        "rack.multithread" => false,
        "rack.multiprocess" => true,
        "rack.run_once" => false,
        "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
      })

      begin
        status, headers, body = app.call(env)
      rescue Exception => e
        warn "#{e.class}: #{e.message}"
        warn e.backtrace.join("\n")
        status, headers, body = SERVER_ERROR
      end

      begin
        debug "Sending response: #{status}"
        NetString.write(sock, status.to_s)
        NetString.write(sock, headers.to_json)

        body.each do |part|
          NetString.write(sock, part) if part.length > 0
        end
        NetString.write(sock, "")
      ensure
        body.close if body.respond_to?(:close)
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
