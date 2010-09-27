require 'nack'
require 'nack/netstring'

require 'test/unit'
require 'stringio'

class TestNetString < Test::Unit::TestCase
  include Nack::NetString

  def test_length
    assert_equal 3, length("3:abc,")
    assert_equal 0, length("0:,")
    assert_equal 30, length("30:")
    assert_equal 999999999, length("999999999:")
    assert_equal false, length("30")
    assert_raise(Nack::Error) { length(":") }
    assert_raise(Nack::Error) { length("a:") }
    assert_raise(Nack::Error) { length("0a:") }
    assert_raise(Nack::Error) { length("01:a") }
    assert_raise(Nack::Error) { length("1000000000:") }
  end

  def test_decode
    assert_equal "abc", decode("3:abc,")
    assert_equal "", decode("0:,")
    assert_equal false, decode("30")
    assert_equal false, decode("30:abc")
    assert_raise(Nack::Error) { decode(":") }
    assert_raise(Nack::Error) { decode("a:") }
    assert_raise(Nack::Error) { decode("01:a") }
    assert_raise(Nack::Error) { decode("1:ab,") }
  end

  def test_read
    buf, io = [], StringIO.new("3:abc,1:a,1:b,5:hello,1:c")
    read(io) { |s| buf << s }
    assert_equal ["abc", "a", "b", "hello", "c"], buf

    io = StringIO.new("4:abc,1:a,")
    assert_raise(Nack::Error) { read(io) { |s| s } }
  end

  def test_encode
    assert_equal "12:hello world!,", encode("hello world!")
    assert_equal "3:abc,", encode("abc")
    assert_equal "1:a,", encode("a")
    assert_equal "0:,", encode("")
  end

  def test_write
    io = StringIO.new
    write(io, "abc")
    assert_equal "3:abc,", io.string
  end
end
