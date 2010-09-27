require 'strscan'
require 'nack/error'

module Nack
  module NetString
    def length(str)
      s = StringScanner.new(str)
      s.scan_until(/\d+/)

      if len = s.matched
        len = len.to_i

        if s.getch == ':'
          len
        else
          false
        end
      else
        raise Error
      end
    end
    module_function :length

    def decode(str)
      len = length(str)

      if len == false
        return false
      end

      offset = "#{len}:".length
      last   = offset+len

      if str.length < last
        false
      else
        str[offset...last]
      end
    end
    module_function :decode

    def parse(io)
      buf = ""

      until io.eof?
        buf += io.read(1)
        len = length(buf)

        if len
          io.read(len, buf)
          yield buf
          io.read(1)
          buf = ""
        end
      end

      nil
    end
    module_function :parse

    def encode(str)
      "#{str.length}:#{str},"
    end
    module_function :encode
  end
end
