require 'fcntl'
require 'json'
require 'socket'
require 'stringio'

require 'nack/error'
require 'nack/netstring'

module Nack
  class Server
    def self.run(*args)
      new(*args).start
    end

    attr_accessor :app, :file, :pipe
    attr_accessor :name, :request_count

    def initialize(app, options = {})
      # Lazy require rack
      require 'rack'

      self.app = app

      self.file = options[:file]
      self.pipe = options[:pipe]

      self.name = options[:name] || "app"
      self.request_count = 0
    end

    def open_server
      if file
        File.unlink(file) if File.exist?(file)
        UNIXServer.open(file)
      else
        raise Error, "no socket given"
      end
    end

    def start
      server = open_server
      ppid = Process.ppid
      self_pipe = nil

      at_exit do
        debug "Closing server"

        server.close unless server.closed?
        self_pipe.close if self_pipe && !self_pipe.closed?

        File.unlink(file) if file && File.exist?(file)
        File.unlink(pipe) if pipe && File.exist?(pipe)
      end

      trap('TERM') { debug "Received TERM"; exit }
      trap('INT')  { debug "Received INT"; exit }
      trap('QUIT') { debug "Received QUIT"; server.close }

      if pipe
        if !File.pipe?(pipe)
          raise Errno::EPIPE, pipe
        end

        a = open(pipe, 'w')
        a.write $$.to_s
        a.close

        self_pipe = open(pipe, 'r', Fcntl::O_NONBLOCK)
        self_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      end

      clients = []
      buffers = {}

      loop do
        $0 = "nack worker [#{name}] (#{request_count})"

        listeners = clients + [self_pipe]
        listeners << server unless server.closed?

        readable, writable = nil
        begin
          readable, writable = IO.select(listeners, nil, [self_pipe], 60)
        rescue Errno::EBADF
        end

        if server.closed? && clients.empty?
          debug "Server closed"
          return
        end

        if ppid != Process.ppid
          debug "Process is orphaned"
          return
        end

        next unless readable

        readable.each do |sock|
          if sock == self_pipe
            begin
              sock.read_nonblock(1024)
            rescue EOFError
              debug "Pipe closed"
              return
            end
          elsif sock == server
            clients << server.accept_nonblock
          else
            client, buf = sock, buffers[sock] ||= ''

            begin
              buf << client.read_nonblock(1024)
            rescue EOFError
              handle sock, StringIO.new(buf)
              buffers.delete(client)
              clients.delete(client)
            end
          end
        end
      end

      nil
    rescue Errno::EINTR
    end

    def handle(sock, buf)
      self.request_count += 1
      debug "Accepted connection"

      status  = 500
      headers = { 'Content-Type' => 'text/html' }
      body    = ["Internal Server Error"]

      env, input = nil, StringIO.new
      begin
        NetString.read(buf) do |data|
          if env.nil?
            env = JSON.parse(data)
          elsif data.length > 0
            input.write(data)
          else
            break
          end
        end
      rescue Nack::Error, JSON::ParserError
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
          status  = 500
          headers = { 'Content-Type' => 'text/html' }
          body    = ["Internal Server Error"]

          headers['X-Nack-Error'] = {
            :name    => e.class,
            :message => e.message,
            :stack   => e.backtrace.join("\n")
          }
        end
      else
        debug "Received bad request"
        status  = 400
        headers = { 'Content-Type' => 'text/html' }
        body    = ["Bad Request"]
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
