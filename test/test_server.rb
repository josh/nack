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

  def tmp_sock
    pid  = Process.pid
    rand = (rand() * 10000000000).floor
    "/tmp/nack.#{pid}.#{rand}.sock"
  end
end

class TestUnixServer < Test::Unit::TestCase
  include Nack
  include ServerTests

  APP = lambda do |env|
    body = env["rack.input"].read
    [200, {"Content-Type" => "text/plain"}, [body]]
  end

  attr_accessor :sock, :pid

  def setup
    self.sock = tmp_sock

    self.pid = fork do
      Server.run(APP, :file => sock)
    end
  end

  def teardown
    Process.kill('KILL', pid)
    Process.wait(pid)

    File.unlink(sock) if File.exist?(sock)
  end

  def client
    until File.exist?(sock)
      sleep 0.1
    end

    Client.open(sock)
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

  attr_accessor :sock, :pid

  def setup
    self.sock = tmp_sock

    self.pid = fork do
      exec "nackup", "--file", sock, CONFIG
    end
  end

  def teardown
    Process.kill('KILL', pid)
    Process.wait(pid)

    File.unlink(sock) if File.exist?(sock)
  end

  def client
    until File.exist?(sock)
      sleep 0.1
    end

    Client.open(sock)
  end
end
