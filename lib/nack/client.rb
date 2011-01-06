require 'json'
require 'socket'

module Nack
  class Client
    def self.open(*args)
      new(*args)
    end

    attr_accessor :file, :socket

    def initialize(*args)
      self.file = args[0]
      self.socket = open_socket
    end

    def open_socket
      UNIXSocket.open(file)
    end

    def request(env = {}, body = nil)
      NetString.write(socket, env.to_json)
      NetString.write(socket, body) if body
      NetString.write(socket, "")

      socket.close_write

      status, headers, body = nil, nil, []

      NetString.read(socket) do |data|
        if status.nil?
          status = data.to_i
        elsif headers.nil?
          headers = JSON.parse(data)
        elsif data.length > 0
          body << data
        else
          # break
        end
      end

      [status, headers, body]
    end
  end
end
