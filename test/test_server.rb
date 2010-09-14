require 'nack'
require 'nack/client'
require 'nack/server'

require 'test/unit'

class TestServer < Test::Unit::TestCase
  include Nack

  APP = lambda do |env|
    body = env["rack.input"].read
    [200, {"Content-Type" => "text/plain"}, [body]]
  end
  SOCK = File.expand_path("../nack.sock", __FILE__)

  def setup
    @pid = fork do
      Server.run(APP, SOCK)
    end

    until File.exist?(SOCK)
      sleep 0.1
    end
  end

  def teardown
    Process.kill('TERM', @pid)
    Process.wait

    File.unlink(SOCK) if File.exist?(SOCK)
  end

  def test_request
    client = Client.new(SOCK)
    status, headers, body = client.request({}, "foo=bar")

    assert_equal 200, status
    assert_equal ["foo=bar"], body
  end

  def test_multiple_requests
    client = Client.new(SOCK)

    status, headers, body = client.request
    assert_equal 200, status

    status, headers, body = client.request
    assert_equal 200, status
  end
end
