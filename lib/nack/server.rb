require 'json'
require 'socket'
require 'stringio'

module Nack
  class Server
    SERVER_ERROR = [500, { "Content-Type" => "text/html" }, ["Internal Server Error"]]
    BAD_REQUEST  = [400, { "Content-Type" => "text/html" }, ["Bad Request"]]

    def self.run(*args)
      new(*args).start
    end

    attr_accessor :state, :app, :host, :port, :file, :onready
    attr_accessor :name, :request_count

    def initialize(app, options = {})
      # Lazy require rack
      require 'rack'

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

    def close
      self.state = :quit
      server.close
      nil
    end

    def accept?
      state == :ready && !server.closed?
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

        at_exit do
          debug "Removing sock #{file}"
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
      trap('TERM') { exit }
      trap('INT')  { exit }
      trap('QUIT') { close }
    end

    def accept!
      if accept?
        server.accept
      else
        nil
      end
    rescue Errno::EBADF, SystemExit
      nil
    rescue Exception => e
      warn "#{e.class}: #{e.message}"
      warn e.backtrace.join("\n")
      nil
    end

    def start
      start_server!
      install_handlers!

      while conn = accept!
        $0 = "nack worker [#{name}] (#{request_count})"
        debug "Waiting for connection"
        handle conn
      end

      nil
    end

    def handle(sock)
      self.request_count += 1
      debug "Accepted connection"

      status, headers, body = SERVER_ERROR

      env, input = nil, StringIO.new
      NetString.read(sock) do |data|
        if env.nil?
          begin
            env = JSON.parse(data)
          rescue JSON::ParserError
            break
          end
        elsif data.length > 0
          input.write(data)
        else
          # break
        end
      end

      sock.close_read
      input.rewind

      if env
        method, path = env['REQUEST_METHOD'], env['PATH_INFO']
        debug "Received request: #{method} #{path}"
        $0 = "nack worker [#{name}] (#{request_count}) #{method} #{path}"

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
      else
        debug "Received bad request"
        status, headers, body = BAD_REQUEST
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
