require 'nack/server'
require 'json'

require 'test/unit'

class TestNackWorker < Test::Unit::TestCase
  include Nack

  attr_accessor :sock, :pid, :heartbeat

  def spawn(fixture)
    config = File.expand_path("../fixtures/#{fixture}.ru", __FILE__)

    pid  = Process.pid
    rand = (rand() * 10000000000).floor

    self.sock = "/tmp/nack.#{pid}.#{rand}.sock"

    self.pid = fork do
      exec "nack_worker", config, sock
    end

    until File.exist?(sock); end
    self.heartbeat = UNIXSocket.open(sock)
  end

  def wait
    Process.kill('TERM', self.pid)
    Process.wait(self.pid)
    self.heartbeat.close if self.heartbeat
  rescue Errno::ESRCH
  end

  def start(fixture = :echo)
    spawn(fixture)
    assert_equal "#{self.pid}\n", heartbeat.readline
    yield
  ensure
    wait
  end

  def request(env = {}, body = nil)
    socket = UNIXSocket.open(sock)

    NetString.write(socket, env.to_json)
    NetString.write(socket, body) if body
    NetString.write(socket, "")

    socket.close_write

    status, headers, body = nil, nil, []

    NetString.read(socket) do |data|
      if status.nil?
        status = data.to_i
      elsif headers.nil?
        headers = JSON.parse(data)
      elsif data.length > 0
        body << data
      else
        # break
      end
    end

    [status, headers, body]
  end

  def test_request
    start do
      status, headers, body = request({}, "foo=bar")

      assert_equal 200, status
      assert_equal "text/plain", headers['Content-Type']
      assert_equal "foo=1\nbar=2", headers['Set-Cookie']
      assert_equal ["foo=bar"], body
    end
  end

  def test_multiple_requests
    start do
      status, headers, body = request
      assert_equal 200, status

      status, headers, body = request
      assert_equal 200, status
    end
  end

  def test_invalid_json_env
    start do
      socket = UNIXSocket.open(sock)

      NetString.write(socket, "")
      socket.close_write

      error = nil

      NetString.read(socket) do |data|
        error = JSON.parse(data)
      end

      assert error
      assert_equal "JSON::ParserError", error['name']
      assert_equal "A JSON text must at least contain two octets!", error['message']
    end
  end

  def test_invalid_netstring
    start do
      socket = UNIXSocket.open(sock)

      socket.write("1:{},")
      socket.close_write

      status, headers, body = nil, nil, []

      error = nil

      NetString.read(socket) do |data|
        error = JSON.parse(data)
      end

      assert error
      assert_equal "Nack::Error", error['name']
      assert_equal "Invalid netstring length, expected to be 1", error['message']
    end
  end

  def test_close_heartbeat
    start do
      status, headers, body = request({}, "foo=bar")
      assert_equal 200, status

      heartbeat.close
      Process.wait(pid)
    end
  end

  def test_app_error
    start :error do
      socket = UNIXSocket.open(sock)

      NetString.write(socket, {}.to_json)
      NetString.write(socket, "foo=bar")
      NetString.write(socket, "")

      socket.close_write

      error = nil

      NetString.read(socket) do |data|
        error = JSON.parse(data)
      end

      assert error
      assert_equal "RuntimeError", error['name']
      assert_equal "b00m", error['message']
    end
  end

  def test_spawn_error
    out = spawn :crash
    error = JSON.parse(heartbeat.read)

    assert error
    assert_equal "RuntimeError", error['name']
    assert_equal "b00m", error['message']
  end
end
