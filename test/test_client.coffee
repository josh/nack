http = require 'http'

{createProcess}    = require 'nack/process'
{createConnection} = require 'nack/client'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

exports.testClientRequest = (test) ->
  test.expect 14

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

    request.end()

    request.on 'close', ->
      test.ok true

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode
      test.equals client, response.client

      body = ""
      response.on 'data', (chunk) ->
        test.ok true
        body += chunk

      response.on 'end', ->
        test.same "Hello World\n", body

        process.quit()

  process.on 'exit', ->
    test.ok true
    test.done()

exports.testProxyRequest = (test) ->
  test.expect 8

  process = createProcess config
  process.spawn()

  server = http.createServer (req, res) ->
    test.ok req
    test.ok res

    client = createConnection process.sockPath
    test.ok client

    client.proxyRequest req, res, ->
      test.ok true
      process.quit()

  server.on 'close', ->
    test.ok true

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
