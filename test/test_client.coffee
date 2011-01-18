http = require 'http'
net  = require 'net'

{createProcess}    = require 'nack/process'
{createConnection} = require 'nack/client'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

createDuplexServer = if net.createServer().allowHalfOpen?
  (listener) ->
    server = net.createServer allowHalfOpen: true
    server.on 'connection', listener
    server
else
  (listener) -> net.createServer listener

exports.testClientRequestBeforeConnect = (test) ->
  test.expect 14

  process = createProcess config
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    request = client.request 'GET', '/foo', {}
    test.ok request
    test.same "GET", request.method
    test.same "/foo", request.path
    test.same "/foo", request.env['PATH_INFO']

    test.ok request.writeable
    test.same false, request.write "foo=bar"

    request.end()

    request.on 'drain', () ->
      test.ok true

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode
      test.equals client, response.client

      body = ""
      response.on 'data', (chunk) ->
        body += chunk

      response.on 'end', ->
        test.same "Hello World\n", body
        test.ok response.completed

        process.quit()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientRequestAfterConnect = (test) ->
  test.expect 13

  process = createProcess config
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    client.on 'connect', ->
      request = client.request 'GET', '/foo', {}
      test.ok request
      test.same "GET", request.method
      test.same "/foo", request.path
      test.same "/foo", request.env['PATH_INFO']

      test.ok request.writeable
      test.same true, request.write "foo=bar"

      request.end()

      request.on 'drain', () ->
        test.ok false

      request.on 'response', (response) ->
        test.ok response
        test.same 200, response.statusCode
        test.equals client, response.client

        body = ""
        response.on 'data', (chunk) ->
          body += chunk

        response.on 'end', ->
          test.same "Hello World\n", body
          test.ok response.completed

          process.quit()

    client.reconnect()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientMultipleRequest = (test) ->
  test.expect 8

  process = createProcess config
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    receivedRequests = 0
    handleResponse = (response) ->
      test.ok response
      test.same 200, response.statusCode

      response.on 'end', ->
        receivedRequests++

        if receivedRequests is 3
          process.quit()

    request1 = client.request 'GET', '/foo', {}
    request1.write "foo=bar"
    request1.end()
    request1.on 'response', handleResponse

    request2 = client.request 'GET', '/bar', {}
    request2.write "bar=baz"
    request2.end()
    request2.on 'response', handleResponse

    request3 = client.request 'GET', '/bar', {}
    request3.write "baz=biz"
    request3.end()
    request3.on 'response', handleResponse

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientRequestWithCookies = (test) ->
  test.expect 8

  process = createProcess __dirname + "/fixtures/echo.ru"
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    request = client.request 'GET', '/foo', {}
    test.ok request

    request.write "foo=bar"
    request.end()

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode
      test.same 'text/plain', response.headers['Content-Type']
      test.same "foo=1\r\nSet-Cookie: bar=2", response.headers['Set-Cookie']

      body = ""
      response.on 'data', (chunk) ->
        body += chunk

      response.on 'end', ->
        test.same "foo=bar", body

        process.quit()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testProxyRequest = (test) ->
  test.expect 9

  process = createProcess config
  process.spawn()

  server = http.createServer (req, res) ->
    test.ok req
    test.ok res

    client = createConnection process.sockPath
    test.ok client

    request = client.proxyRequest req, res
    test.ok request
    test.ok request.writeable

    request.on 'response', (response) ->
      response.on 'end', ->
        test.ok true
        process.quit()

  process.once 'ready', ->
    server.listen PORT
    server.on 'listening', ->
      http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
        test.ifError err
        test.same "Hello World\n", data
        server.close()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientUncompletedResponse = (test) ->
  test.expect 3

  sockPath = "/tmp/nack.test.sock"

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', () ->
      conn.write "3:200,"
      conn.end()

  worker.listen sockPath, () ->
    client = createConnection sockPath

    client.on 'close', ->
      test.done()

    client.on 'error', (exception) ->
      test.ok exception

    test.ok client

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

exports.testClientUncompletedRequest = (test) ->
  test.expect 3

  sockPath = "/tmp/nack.test.sock"

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'data', () ->
      conn.end()

  worker.listen sockPath, () ->
    client = createConnection sockPath

    client.on 'close', ->
      test.done()

    client.on 'error', (exception) ->
      test.ok exception

    test.ok client

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

exports.testClientInvalidStatusResponse = (test) ->
  test.expect 3

  sockPath = "/tmp/nack.test.sock"

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', () ->
      conn.write "2:{},"
      conn.write "2:{},"
      conn.write "0:,"
      conn.end()

  worker.listen sockPath, () ->
    client = createConnection sockPath

    client.on 'close', ->
      test.done()

    client.on 'error', (exception) ->
      test.ok exception

    test.ok client

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

exports.testClientInvalidHeadersResponse = (test) ->
  test.expect 3

  sockPath = "/tmp/nack.test.sock"

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', () ->
      conn.write "3:200,"
      conn.write "3:100,"
      conn.write "0:,"
      conn.end()

  worker.listen sockPath, () ->
    client = createConnection sockPath

    client.on 'close', ->
      test.done()

    client.on 'error', (exception) ->
      test.ok exception

    test.ok client

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

exports.testClientMissingHeadersResponse = (test) ->
  test.expect 3

  sockPath = "/tmp/nack.test.sock"

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', () ->
      conn.write "3:200,"
      conn.write "0:,"
      conn.end()

  worker.listen sockPath, () ->
    client = createConnection sockPath

    client.on 'close', ->
      test.done()

    client.on 'error', (exception) ->
      test.ok exception

    test.ok client

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

exports.testClientException = (test) ->
  test.expect 4

  process = createProcess __dirname + "/fixtures/error.ru"
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    client.on 'close', ->
      process.quit()

    client.on 'error', (exception) ->
      test.same "b00m", exception.message

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

  process.on 'exit', ->
    test.ok true
    test.done()
