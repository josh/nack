http = require 'http'

{createProcess}    = require 'nack/process'
{createConnection} = require 'nack/client'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

exports.testClientRequestBeforeConnect = (test) ->
  test.expect 13

  process = createProcess config
  process.spawn()

  process.onNext 'ready', ->
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

        process.quit()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientRequestAfterConnect = (test) ->
  test.expect 12

  process = createProcess config
  process.spawn()

  process.onNext 'ready', ->
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

          process.quit()

    client.reconnect()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testClientMultipleRequest = (test) ->
  test.expect 8

  process = createProcess config
  process.spawn()

  process.onNext 'ready', ->
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

  process.onNext 'ready', ->
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

  process.onNext 'ready', ->
    server.listen PORT
    server.on 'listening', ->
      http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
        test.ok !err
        test.same "Hello World\n", data
        server.close()

  process.on 'exit', ->
    test.ok true
    test.done()
