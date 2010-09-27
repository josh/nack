require 'strscan'
require 'nack/error'

module Nack
  # http://cr.yp.to/proto/netstrings.txt
  module NetString
    def length(str)
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
          false
        else
          raise Error, "Unexpected character '#{s.peek(1)}' found at offset #{s.pos}"
        end
      elsif s.peek(1) == ':'
        raise Error, "Invalid netstring with leading ':'"
      else
        raise Error, "Unexpected character '#{s.peek(1)}' found at offset #{s.pos}"
      end
    end
    module_function :length

    def decode(str)
      len = length(str)

      if len == false
        return false
      end

      offset = "#{len}:".length
      last   = offset + len

      if str.length < last
        false
      else
        if str[last] != ?,
          raise Error, "Invalid netstring length, expected to be #{len}"
        else
          str[offset...last]
        end
      end
    end
    module_function :decode

    def read(io)
      buf = ""

      until io.eof?
        buf += io.readline(":")
        len = length(buf)

        if len
          io.read(len, buf)

          yield buf

          c = io.getc
          if c && c != ?,
            raise Error, "Invalid netstring length, expected to be #{len}"
          end

          buf = ""
        end
      end

      nil
    end
    module_function :read

    def encode(str)
      "#{str.length}:#{str},"
    end
    module_function :encode

    def write(io, str)
      io << "#{str.size}:" << str << ","
      io.flush
    end
    module_function :encode
  end
end
