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
    assert_equal false, length("30")
    assert_raise(Nack::Error) { length(":") }
    assert_raise(Nack::Error) { length("a:") }
  end

  def test_decode
    assert_equal "abc", decode("3:abc,")
    assert_equal "", decode("0:,")
    assert_equal false, decode("30")
    assert_equal false, decode("30:abc")
  end

  def test_parse
    io = StringIO.new("3:abc,1:a,1:b,5:hello,1:c")

    strings = []
    parse(io) do |str|
      strings << str
    end

    assert_equal ["abc", "a", "b", "hello", "c"], strings
  end

  def test_encode
    assert_equal "12:hello world!,", encode("hello world!")
    assert_equal "3:abc,", encode("abc")
    assert_equal "1:a,", encode("a")
    assert_equal "0:,", encode("")
  end
end
