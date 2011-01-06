require 'nack/server'

require 'test/unit'

class TestNackWorker < Test::Unit::TestCase
  include Nack

  CONFIG = File.expand_path("../fixtures/echo.ru", __FILE__)

  attr_accessor :sock, :pipe, :pid, :self_pipe

  def setup
    self.sock = tmp_sock
    self.pipe = tmp_pipe

    self.pid = fork do
      exec "nack_worker", "--file", sock, "--pipe", pipe, CONFIG
    end

    assert_equal pid, open(pipe).read.to_i
    self.self_pipe = open(pipe, 'w')
  end

  def teardown
    Process.kill('TERM', pid)
    Process.wait(pid)
    self_pipe.close
  rescue Errno::ESRCH
  end

  def test_request
    status, headers, body = request({}, "foo=bar")

    assert_equal 200, status
    assert_equal "text/plain", headers['Content-Type']
    assert_equal "foo=1\nbar=2", headers['Set-Cookie']
    assert_equal ["foo=bar"], body
  end

  def test_multiple_requests
    status, headers, body = request
    assert_equal 200, status

    status, headers, body = request
    assert_equal 200, status
  end

  def test_invalid_json_env
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

  def test_invalid_netstring
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

  def test_close_pipe
    status, headers, body = request({}, "foo=bar")
    assert_equal 200, status

    self_pipe.close
    Process.wait(pid)
  end

  def tmp_sock
    pid  = Process.pid
    rand = (rand() * 10000000000).floor
    "/tmp/nack.#{pid}.#{rand}.sock"
  end

  def tmp_pipe
    pid  = Process.pid
    rand = (rand() * 10000000000).floor
    path = "/tmp/nack.#{pid}.#{rand}.pipe"
    system "mkfifo", path
    path
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
end
