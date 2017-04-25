module Nack
  class Isolated
    def self.eval &block
      new.eval(&block)
    end

    def eval
      read, write = IO.pipe

      # Run some code in an isolated child process, pipe the results back.
      pid = fork do
        write.write _serialize(yield)
        # Avoid parent's at_exit hooks (like socket file cleanup).
        exit!
      end

      Process.wait(pid)
      write.close
      retval = _deserialize(read.read)
      read.close
      retval
    end

    def _serialize val
      [Marshal.dump(val)].pack("m")
    end

    def _deserialize val
      Marshal.load(val.unpack("m").first)
    end
  end
end
