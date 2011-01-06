require 'strscan'
require 'nack/error'

module Nack
  # http://cr.yp.to/proto/netstrings.txt
  module NetString
    def ns_length(str)
      s = StringScanner.new(str)

      if slen = s.scan(/\d+/)
        if slen =~ /^0\d+$/
          raise Error, "Invalid netstring with leading 0"
        elsif slen.length > 9
          raise Error, "netstring is too large"
        end

        len = Integer(slen)

        if s.scan(/:/)
          len
        elsif s.eos?
          raise Error, "Invalid netstring terminated after length"
        else
          raise Error, "Unexpected character '#{s.peek(1)}' found at offset #{s.pos}"
        end
      elsif s.peek(1) == ':'
        raise Error, "Invalid netstring with leading ':'"
      else
        raise Error, "Unexpected character '#{s.peek(1)}' found at offset #{s.pos}"
      end
    end
    module_function :ns_length
    protected :ns_length

    def read(io)
      buf = ""

      until io.eof?
        buf << io.readline(":")
        len = ns_length(buf)

        io.read(len, buf)

        if io.eof?
          return
        elsif (c = io.getc) && c != ?,
          raise Error, "Invalid netstring length, expected to be #{len}"
        else
          yield buf
        end

        buf = ""
      end

      nil
    end
    module_function :read

    def encode(str)
      io = StringIO.new
      write(io, str)
      io.string
    end
    module_function :encode

    def write(io, str)
      io << "#{str.bytesize}:" << str << ","
      io.flush
    end
    module_function :write
  end
end
