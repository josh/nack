require 'nack'
require 'nack/client'
require 'nack/server'

require 'test/unit'

module ServerTests
  def test_request
    status, headers, body = client.request({}, "foo=bar")

    assert_equal 200, status
    assert_equal ["foo=bar"], body
  end

  def test_multiple_requests
    status, headers, body = client.request
    assert_equal 200, status

    status, headers, body = client.request
    assert_equal 200, status
  end
end

class TestUnixServer < Test::Unit::TestCase
  include Nack
  include ServerTests

  APP = lambda do |env|
    body = env["rack.input"].read
    [200, {"Content-Type" => "text/plain"}, [body]]
  end
  SOCK = File.expand_path("../nack.sock", __FILE__)

  attr_accessor :pid

  def setup
    self.pid = fork do
      Server.run(APP, :file => SOCK)
    end
  end

  def teardown
    Process.kill('KILL', pid)
    Process.wait(pid)

    File.unlink(SOCK) if File.exist?(SOCK)
  end

  def client
    until File.exist?(SOCK)
      sleep 0.1
    end

    Client.open(SOCK)
  end
end

class TestTCPServer < Test::Unit::TestCase
  include Nack
  include ServerTests

  APP = lambda do |env|
    body = env["rack.input"].read
    [200, {"Content-Type" => "text/plain"}, [body]]
  end
  HOST = "localhost"
  PORT = 8080

  attr_accessor :pid

  def setup
    self.pid = fork do
      Server.run(APP, :host => HOST, :port => PORT)
    end
  end

  def teardown
    Process.kill('KILL', pid)
    Process.wait(pid)
  end

  def client
    begin
      Client.open(HOST, PORT)
    rescue Errno::ECONNREFUSED
      sleep 0.1
      retry
    end
  end
end

class TestNackup < Test::Unit::TestCase
  include Nack
  include ServerTests

  CONFIG = File.expand_path("../fixtures/echo.ru", __FILE__)
  SOCK = File.expand_path("../nack.sock", __FILE__)

  attr_accessor :pid

  def setup
    self.pid = fork do
      exec File.expand_path("../../bin/nackup", __FILE__), "--file", SOCK, CONFIG
    end
  end

  def teardown
    Process.kill('KILL', pid)
    Process.wait(pid)

    File.unlink(SOCK) if File.exist?(SOCK)
  end

  def client
    until File.exist?(SOCK)
      sleep 0.1
    end

    Client.open(SOCK)
  end
end
