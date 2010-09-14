require 'socket'
require 'yajl'

module Nack
  class Client
    CRLF = "\r\n"

    attr_accessor :path

    def initialize(path)
      self.path = path
    end

    def request(env = {}, body = nil)
      sock = UNIXSocket.open(path)

      encoder = Yajl::Encoder.new

      encoder.encode(env, sock)
      sock.write(CRLF)

      if body
        encoder.encode(body, sock)
        sock.write(CRLF)
      end

      sock.close_write

      status, headers, body = nil, nil, []

      Yajl::Parser.parse(sock) do |obj|
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
