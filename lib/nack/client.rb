require 'json'
require 'socket'

require 'nack/netstring'

module Nack
  class Client
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
      socket.write(NetString.encode(env.to_json))

      if body
        socket.write(NetString.encode(body))
      end

      socket.close_write

      status, headers, body = nil, nil, []

      NetString.parse(socket) do |data|
        if status.nil?
          status = data.to_i
        elsif headers.nil?
          headers = JSON.parse(data)
        else
          body << data
        end
      end

      [status, headers, body]
    end
  end
end
