require 'socket'
require 'yajl'

module Nack
  class Client
    CRLF = "\r\n"

    def self.open(*args)
      new(*args)
    end

    attr_accessor :file, :host, :port,
                  :socket

    def initialize(*args)
      case args.length
      when 1
        self.file = args[0]
      when 2
        self.host = args[0]
        self.port = args[1]
      end

      self.socket = open_socket
    end

    def open_socket
      if file
        UNIXSocket.open(file)
      elsif host && port
        TCPSocket.open(host, port)
      end
    end

    def request(env = {}, body = nil)
      encoder = Yajl::Encoder.new

      encoder.encode(env, socket)
      socket.write(CRLF)

      if body
        encoder.encode(body, socket)
        socket.write(CRLF)
      end

      socket.close_write

      status, headers, body = nil, nil, []

      Yajl::Parser.parse(socket) do |obj|
        if status.nil?
          status = obj.to_i
        elsif headers.nil?
          headers = obj
        else
          body << obj
        end
      end

      [status, headers, body]
    end
  end
end
