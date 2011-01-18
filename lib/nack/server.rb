require 'fcntl'
require 'socket'
require 'stringio'

require 'nack/builder'
require 'nack/error'
require 'nack/netstring'

module Nack
  class Server
    def self.run(*args)
      new(*args).start
    end

    attr_accessor :config, :app, :file, :pipe
    attr_accessor :ppid, :server, :self_pipe

    def initialize(config, options = {})
      self.config = config

      self.file = options[:file]
      self.pipe = options[:pipe]

      at_exit { cleanup }

      File.unlink(file) if File.exist?(file)

      if !File.pipe?(pipe)
        raise Errno::EPIPE, pipe
      end

      self.ppid = Process.ppid

      load_json_lib!
      self.app = load_config
    rescue Exception => e
      if File.pipe?(pipe)
        open(pipe, Fcntl::O_WRONLY | Fcntl::O_NONBLOCK) do |a|
          a.write_nonblock exception_to_json(e)
        end
        exit 1
      else
        raise e
      end
    end

    def cleanup
      server.close if server && !server.closed?
      self_pipe.close if self_pipe && !self_pipe.closed?

      File.unlink(file) if file && File.exist?(file)
      File.unlink(pipe) if pipe && File.exist?(pipe)
    end

    def load_json_lib!
      begin
        require 'json'
      rescue LoadError
        require 'rubygems'
        require 'json'
      end
    end

    def load_config
      cfgfile = File.read(config)
      eval("Nack::Builder.new {( #{cfgfile}\n )}.to_app", TOPLEVEL_BINDING, config)
    end

    def start
      self.server = UNIXServer.open(file)
      self.self_pipe = nil

      trap('TERM') { exit }
      trap('INT')  { exit }
      trap('QUIT') { server.close }

      open(pipe, Fcntl::O_WRONLY | Fcntl::O_NONBLOCK) do |a|
        a.write_nonblock $$.to_s
      end

      self.self_pipe = open(pipe, 'r', Fcntl::O_NONBLOCK)
      self.self_pipe.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)

      clients = []
      buffers = {}

      loop do
        listeners = clients + [self_pipe]
        listeners << server unless server.closed?

        readable, writable = nil
        begin
          readable, writable = IO.select(listeners, nil, [self_pipe], 60)
        rescue Errno::EBADF
        end

        if server.closed? && clients.empty?
          return
        end

        if ppid != Process.ppid
          return
        end

        next unless readable

        readable.each do |sock|
          if sock == self_pipe
            begin
              sock.read_nonblock(1024)
            rescue EOFError
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
      status  = 500
      headers = { 'Content-Type' => 'text/html' }
      body    = ["Internal Server Error"]

      env, input = nil, StringIO.new

      NetString.read(buf) do |data|
        if env.nil?
          env = JSON.parse(data)
        elsif data.length > 0
          input.write(data)
        else
          break
        end
      end

      sock.close_read
      input.rewind

      method, path = env['REQUEST_METHOD'], env['PATH_INFO']

      env = env.merge({
        "rack.version" => Rack::VERSION,
        "rack.input" => input,
        "rack.errors" => $stderr,
        "rack.multithread" => false,
        "rack.multiprocess" => true,
        "rack.run_once" => false,
        "rack.url_scheme" => ["yes", "on", "1"].include?(env["HTTPS"]) ? "https" : "http"
      })

      status, headers, body = app.call(env)

      begin
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
      NetString.write(sock, exception_to_json(e))
    ensure
      sock.close_write
    end

    def exception_as_json(e)
      { :name    => e.class.name,
        :message => e.message,
        :stack   => e.backtrace.join("\n") }
    end

    def exception_to_json(e)
      exception = exception_as_json(e)
      if exception.respond_to?(:to_json)
        exception.to_json
      else
        <<-JSON
          { "name": #{exception[:name].inspect},
            "message": #{exception[:message].inspect},
            "stack": #{exception[:stack].inspect} }
        JSON
      end
    end
  end
end
