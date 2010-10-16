require 'nack'
require 'nack/client'
require 'nack/server'

require 'test/unit'

module ServerTests
  def test_request
    status, headers, body = client.request({}, "foo=bar")

    assert_equal 200, status
    assert_equal "text/plain", headers['Content-Type']
    assert_equal "foo=1\nbar=2", headers['Set-Cookie']
    assert_equal ["foo=bar"], body
  end

  def test_multiple_requests
    status, headers, body = client.request
    assert_equal 200, status

    status, headers, body = client.request
    assert_equal 200, status
  end

  def test_bad_request
    socket = client.socket

    Nack::NetString.write(socket, "")
    socket.close_write

    status, headers, body = nil, nil, []

    Nack::NetString.read(socket) do |data|
      if status.nil?
        status = data.to_i
      elsif headers.nil?
        headers = JSON.parse(data)
      elsif data.length > 0
        body << data
      else
        socket.close
        break
      end
    end

    assert_equal 400, status
    assert_equal({ "Content-Type" => "text/html" }, headers)
    assert_equal ["Bad Request"], body
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
    [200, {"Content-Type" => "text/plain", "Set-Cookie" => "foo=1\nbar=2"}, [body]]
  end

  attr_accessor :sock, :pid

  def setup
    self.sock = tmp_sock

    rd, wr = IO.pipe

    self.pid = fork do
      $stdout.reopen(wr)
      Server.run(APP, :file => sock, :onready => proc { puts "ready" })
    end

    assert_equal 'ready', rd.readline.chomp
  end

  def teardown
    Process.kill('TERM', pid)
    Process.wait(pid)
  end

  def client
    Client.open(sock)
  end
end

class TestTCPServer < Test::Unit::TestCase
  include Nack
  include ServerTests

  APP = lambda do |env|
    body = env["rack.input"].read
    [200, {"Content-Type" => "text/plain", "Set-Cookie" => "foo=1\nbar=2"}, [body]]
  end
  HOST = "localhost"
  PORT = 8080

  attr_accessor :pid

  def setup
    rd, wr = IO.pipe

    self.pid = fork do
      $stdout.reopen(wr)
      Server.run(APP, :host => HOST, :port => PORT, :onready => proc { puts "ready" })
    end

    assert_equal 'ready', rd.readline.chomp
  end

  def teardown
    Process.kill('TERM', pid)
    Process.wait(pid)
  end

  def client
    Client.open(HOST, PORT)
  end
end

class TestNackWorker < Test::Unit::TestCase
  include Nack
  include ServerTests

  CONFIG = File.expand_path("../fixtures/echo.ru", __FILE__)

  attr_accessor :sock, :pid

  def setup
    self.sock = tmp_sock

    rd, wr = IO.pipe

    self.pid = fork do
      $stdout.reopen(wr)
      exec "nack_worker", "--file", sock, CONFIG
    end

    assert_equal 'ready', rd.readline.chomp
  end

  def teardown
    Process.kill('TERM', pid)
    Process.wait(pid)
  end

  def client
    Client.open(sock)
  end
end
