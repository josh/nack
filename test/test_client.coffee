http = require 'http'
net  = require 'net'

{createProcess, createConnection} = require '..'

config = __dirname + "/fixtures/hello.ru"

createDuplexServer = (listener) ->
  server = net.createServer allowHalfOpen: true
  server.on 'connection', listener
  server

exports.testClientRequestBeforeConnect = (test) ->
  test.expect 12

  process = createProcess config
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    request = client.request 'GET', '/foo', {}
    test.ok request
    test.same "GET", request.method
    test.same "/foo", request.url

    test.ok request.writable
    request.write "foo=bar"

    request.end()

    request.on 'drain', ->
      test.ok true

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode
      test.same '1.1', response.httpVersion
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
  test.expect 11

  process = createProcess config
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    client.on 'connect', ->
      request = client.request 'GET', '/foo', {}
      test.ok request
      test.same "GET", request.method
      test.same "/foo", request.url

      test.ok request.writable
      request.write "foo=bar"

      request.end()

      request.on 'drain', ->
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
  test.expect 10

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

        if receivedRequests is 4
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

    request4 = client.request 'GET', '/bar', {}
    request4.write "baz=bang"
    request4.end()
    request4.on 'response', handleResponse

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientEnvLint = (test) ->
  test.expect 4

  process = createProcess __dirname + "/fixtures/lint.ru"

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    request = client.request 'GET', '/foo', {}
    request.end()

    request.on 'error', (err) ->
      test.ifError err
      test.done()

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode

      process.quit()

  process.on 'exit', ->
    test.ok true
    test.done()

  process.spawn()

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

exports.testClientResponseSendFile = (test) ->
  test.expect 5

  process = createProcess __dirname + "/fixtures/sendfile.ru"

  process.once 'ready', ->
    client  = createConnection process.sockPath
    request = client.request 'GET', '/foo', {}
    request.end()

    request.on 'response', (response) ->
      test.same 200, response.statusCode
      test.same "text/x-script.ruby", response.headers['Content-Type']
      test.same "164", response.headers['Content-Length']
      test.ok !response.headers['X-Sendfile']

      body = ""
      response.on 'data', (chunk) ->
        body += chunk

      response.on 'end', ->
        test.same 164, body.length

        process.quit ->
          test.done()

  process.spawn()

exports.testClientResponseToPath = (test) ->
  test.expect 5

  process = createProcess __dirname + "/fixtures/file.ru"

  process.once 'ready', ->
    client  = createConnection process.sockPath
    request = client.request 'GET', '/file.ru', {}
    request.end()

    request.on 'response', (response) ->
      test.same 200, response.statusCode
      test.same "text/x-script.ruby", response.headers['Content-Type']
      test.same "82", response.headers['Content-Length']
      test.ok !response.headers['X-Sendfile']

      body = ""
      response.on 'data', (chunk) ->
        body += chunk

      response.on 'end', ->
        test.same 82, body.length

        process.quit ->
          test.done()

  process.spawn()

exports.testRequestPipe = (test) ->
  test.expect 9

  process = createProcess config
  process.spawn()

  server = http.createServer (req, res) ->
    test.ok req
    test.ok res

    client = createConnection process.sockPath
    test.ok client

    request = client.request()

    test.ok request
    test.ok request.writable

    request.on 'error', (err) -> test.ifError err

    request.on 'response', (response) ->
      response.pipe res

      response.on 'end', ->
        test.ok true
        process.quit()

    req.pipe request

  process.once 'ready', ->
    server.listen 0
    server.on 'listening', ->
      req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
        test.same 200, res.statusCode
        data = ""
        res.setEncoding 'utf8'
        res.on 'error', (err) -> test.ifError err
        res.on 'data', (chunk) -> data += chunk
        res.on 'end', ->
          test.same "Hello World\n", data
          server.close()
      req.end()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientUncompletedResponse = (test) ->
  test.expect 2

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', () ->
      conn.write "3:200,"
      conn.end()

  worker.listen 0, ->
    client = createConnection worker.address().port

    client.on 'close', ->
      test.done()

    test.ok client

    request = client.request 'GET', '/', {}
    request.on 'error', (exception) ->
      test.ok exception

    request.end()

exports.testClientUncompletedRequest = (test) ->
  test.expect 2

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'data', () ->
      conn.end()

  worker.listen 0, ->
    client = createConnection worker.address().port

    client.on 'close', ->
      test.done()

    test.ok client

    request = client.request 'GET', '/', {}
    request.on 'error', (exception) ->
      test.ok exception

    request.end()

exports.testClientInvalidStatusResponse = (test) ->
  test.expect 2

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', ->
      conn.write "2:{},"
      conn.write "2:{},"
      conn.write "0:,"
      conn.end()

  worker.listen 0, ->
    client = createConnection worker.address().port

    client.on 'close', ->
      test.done()

    test.ok client

    request = client.request 'GET', '/', {}
    request.on 'error', (exception) ->
      test.ok exception

    request.end()

exports.testClientInvalidHeadersResponse = (test) ->
  test.expect 2

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', ->
      conn.write "3:200,"
      conn.write "3:100,"
      conn.write "0:,"
      conn.end()

  worker.listen 0, ->
    client = createConnection worker.address().port

    client.on 'close', ->
      test.done()

    test.ok client

    request = client.request 'GET', '/', {}
    request.on 'error', (exception) ->
      test.ok exception

    request.end()

exports.testClientMissingHeadersResponse = (test) ->
  test.expect 2

  worker = createDuplexServer (conn) ->
    worker.close()

    conn.on 'end', ->
      conn.write "3:200,"
      conn.write "0:,"
      conn.end()

  worker.listen 0, ->
    client = createConnection worker.address().port

    client.on 'close', ->
      test.done()

    test.ok client

    request = client.request 'GET', '/', {}
    request.on 'error', (exception) ->
      test.ok exception

    request.end()

exports.testClientException = (test) ->
  test.expect 3

  process = createProcess __dirname + "/fixtures/error.ru"
  process.spawn()

  process.once 'ready', ->
    client = createConnection process.sockPath
    test.ok client

    client.on 'close', ->
      process.quit()

    request = client.request 'GET', '/', {}
    request.on 'error', (exception) ->
      test.same "b00m", exception.message

    request.end()

  process.on 'exit', ->
    test.ok true
    test.done()
