http    = require 'http'
connect = require 'connect'

{createPool} = require '..'

exports.testProxyRequest = (test) ->
  test.expect 2

  pool = createPool __dirname + "/fixtures/hello.ru"

  app = connect()
    .use(pool.proxy)

  server = http.createServer app

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen 0
  server.on 'listening', ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 200, res.statusCode
      server.close()
    req.end()

exports.testProxyRequestWithClientException = (test) ->
  test.expect 3

  pool = createPool __dirname + "/fixtures/error.ru"

  app = connect()
    .use(pool.proxy)
    .use (err, req, res, next) ->
      test.ok err
      res.writeHead 500, 'Content-Type': 'text/plain'
      res.end()

  server = http.createServer app

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen 0
  server.on 'listening', ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 500, res.statusCode
      server.close()
    req.end()

exports.testProxyRequestWithErrorCreatingProcess = (test) ->
  test.expect 3

  pool = createPool __dirname + "/fixtures/crash.ru"

  app = connect()
    .use(pool.proxy)
    .use (err, req, res, next) ->
      test.ok err
      res.writeHead 500, 'Content-Type': 'text/plain'
      res.end()

  server = http.createServer app

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen 0
  server.on 'listening', ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 500, res.statusCode
      server.close()
    req.end()

exports.testProxyCookies = (test) ->
  test.expect 2

  pool = createPool __dirname + "/fixtures/echo.ru"

  app = connect()
    .use(pool.proxy)

  server = http.createServer app

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen 0
  server.on 'listening', ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 200, res.statusCode
      server.close()
    req.end()

exports.testCloseServer = (test) ->
  test.expect 2

  pool = createPool __dirname + "/fixtures/hello.ru"

  app = connect()
    .use(pool.proxy)

  server = http.createServer app

  server.on 'close', ->
    test.ok true
    test.done()

  server.listen 0
  server.on 'listening', ->
    test.ok true
    server.close()

exports.testCloseUnstartedServer = (test) ->
  test.expect 1

  pool = createPool __dirname + "/fixtures/hello.ru"

  app = connect()
    .use(pool.proxy)

  server = http.createServer app

  test.throws ->
    server.close()

  test.done()
