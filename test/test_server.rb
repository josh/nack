require 'nack/server'
require 'json'

require 'test/unit'

class TestNackWorker < Test::Unit::TestCase
  include Nack

  attr_accessor :sock, :pipe, :pid, :self_pipe

  def spawn(fixture)
    config = File.expand_path("../fixtures/#{fixture}.ru", __FILE__)

    pid  = Process.pid
    rand = (rand() * 10000000000).floor

    self.sock = "/tmp/nack.#{pid}.#{rand}.sock"
    self.pipe = "/tmp/nack.#{pid}.#{rand}.pipe"

    system "mkfifo", pipe

    self.pid = fork do
      exec "nack_worker", config, sock, pipe
    end
  end

  def wait
    Process.kill('TERM', self.pid)
    Process.wait(self.pid)
    self_pipe.close
  rescue Errno::ESRCH
  end

  def start(fixture = :echo)
    spawn(fixture)

    assert_equal self.pid, open(pipe).read.to_i
    self.self_pipe = open(pipe, 'w')

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

      status, headers, body = nil, nil, []

      NetString.read(socket) do |data|
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
  end

  def test_invalid_netstring
    start do
      socket = UNIXSocket.open(sock)

      socket.write("1:{},")
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
          socket.close
          break
        end
      end

      assert_equal 400, status
      assert_equal({ "Content-Type" => "text/html" }, headers)
      assert_equal ["Bad Request"], body
    end
  end

  def test_close_pipe
    start do
      status, headers, body = request({}, "foo=bar")
      assert_equal 200, status

      self_pipe.close
      Process.wait(pid)
    end
  end

  def test_app_error
    start :error do
      status, headers, body = request({}, "foo=bar")

      assert_equal 500, status
      assert headers.key?('X-Nack-Error')
      assert_equal "b00m", headers['X-Nack-Error']['message']
      assert_equal ["Internal Server Error"], body
    end
  end

  def test_spawn_error
    out = spawn :crash
    assert_match "b00m", open(pipe).read
  end
end
