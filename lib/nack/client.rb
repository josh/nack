require 'socket'
require 'yajl'

module Nack
  class Client
    attr_accessor :path

    def initialize(path)
      self.path = path
    end

    def request(env = {}, body = "")
      sock = UNIXSocket.open(path)

      encoder = Yajl::Encoder.new
      encoder.encode(env, sock)
      encoder.encode(body, sock)
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
