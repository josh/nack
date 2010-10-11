# encoding: utf-8

require 'nack'
require 'nack/netstring'

require 'test/unit'
require 'stringio'

class TestNetString < Test::Unit::TestCase
  include Nack::NetString

  def test_read
    buf, io = [], StringIO.new("3:abc,1:a,1:b,5:hello,1:c,0:,")
    read(io) { |s| buf << s }
    assert_equal ["abc", "a", "b", "hello", "c", ""], buf

    buf, io = [], StringIO.new("1:a,5:café,3:☃,")
    read(io) { |s| buf << s }
    if "".respond_to?(:force_encoding)
      assert_equal ["a", "café", "☃"], buf.map { |s| s.force_encoding("UTF-8") }
    else
      assert_equal ["a", "café", "☃"], buf
    end

    buf, io = [], StringIO.new("1:a,5:abc")
    read(io) { |s| buf << s }
    assert_equal ["a"], buf

    io = StringIO.new("4:abc,1:a,")
    assert_raise(Nack::Error) { read(io) { |s| s } }

    io = StringIO.new("30")
    assert_raise(Nack::Error) { read(io) { |s| s } }

    io = StringIO.new(":")
    assert_raise(Nack::Error) { read(io) { |s| s } }

    io = StringIO.new("a:")
    assert_raise(Nack::Error) { read(io) { |s| s } }

    io = StringIO.new("01:a")
    assert_raise(Nack::Error) { read(io) { |s| s } }

    io = StringIO.new("1000000000:a")
    assert_raise(Nack::Error) { read(io) { |s| s } }
  end

  def test_resume_reading
    io = StringIO.new("3:abc,1:a,1:b,0:,5:hello,1:c,0:,2:42,")

    buf = []
    read(io) { |s| s.length > 0 ? buf << s : break }
    assert_equal ["abc", "a", "b"], buf

    buf = []
    read(io) { |s| s.length > 0 ? buf << s : break }
    assert_equal ["hello", "c"], buf

    buf = []
    read(io) { |s| s.length > 0 ? buf << s : break }
    assert_equal ["42"], buf
  end

  def test_encode
    assert_equal "12:hello world!,", encode("hello world!")
    assert_equal [0x31, 0x32, 0x3a, 0x68, 0x65, 0x6c, 0x6c, 0x6f,
                  0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21, 0x2c],
      encode("hello world!").unpack("c*")
    assert_equal "3:abc,", encode("abc")
    assert_equal "1:a,", encode("a")
    assert_equal "5:café,", encode("café")
    assert_equal "0:,", encode("")
  end

  def test_write
    io = StringIO.new
    write(io, "abc")
    assert_equal "3:abc,", io.string
  end
end
