http = require 'http'

{createServer} = require 'nack/server'

PORT = 8080

exports.testProxyRequest = (test) ->
  test.expect 2

  server = createServer __dirname + "/fixtures/hello.ru"

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok !err
      server.close()

exports.testProxyCookies = (test) ->
  test.expect 2

  server = createServer __dirname + "/fixtures/echo.ru"

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok !err
      server.close()

exports.testCloseServer = (test) ->
  test.expect 2

  server = createServer __dirname + "/fixtures/hello.ru"

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen PORT
  server.on 'listening', ->
    test.ok true
    server.close()

exports.testCloseUnstartedServer = (test) ->
  test.expect 1

  server = createServer __dirname + "/fixtures/hello.ru"

  server.on 'close', ->
    test.ok true
    test.done()

  server.close()
