async = require 'async'
http  = require 'http'

{createPool} = require '..'

config = __dirname + "/fixtures/hello.ru"

exports.testCreatePoolEvents = (test) ->
  test.expect 5

  pool = createPool config, size: 2
  test.same 2, pool.workers.length
  test.same 0, pool.getReadyWorkerCount()

  pool.once 'ready', ->
    test.ok pool.getReadyWorkerCount() > 0

  pool.on 'worker:ready', ->
    if pool.getReadyWorkerCount() == 2
      pool.quit()

  pool.on 'error', (error) ->
    test.ifError error

  pool.on 'exit', ->
    test.same 2, pool.workers.length
    test.same 0, pool.getReadyWorkerCount()
    test.done()

  pool.spawn()

exports.testCreatePoolWorkerEvents = (test) ->
  test.expect 4

  count = 0

  pool = createPool config, size: 2
  test.same 2, pool.workers.length
  test.same 0, pool.getReadyWorkerCount()

  pool.on 'worker:ready', ->
    count++

    if pool.getReadyWorkerCount() == 2
      test.same 2, pool.workers.length
      pool.quit()

  pool.on 'worker:exit', ->
    count--

    if count is 0
      test.same 0, pool.getReadyWorkerCount()
      test.done()

  pool.on 'error', (error) ->
    test.ifError error

  pool.spawn()

exports.testPoolRestart = (test) ->
  test.expect 3

  pool = createPool config, size: 2

  onAllReady = (callback) ->
    onReady = ->
      if pool.getReadyWorkerCount() == 2
        pool.removeListener 'worker:ready', onReady
        callback()
    pool.on 'worker:ready', onReady

  onAllReady ->
    test.ok true
    pool.restart ->
      test.ok true

    onAllReady ->
      test.ok true

      pool.on 'exit', ->
        test.done()

      pool.quit()

  pool.spawn()

exports.testRestartWithNoActiveWorkers = (test) ->
  test.expect 2

  pool = createPool config, size: 2

  pool.restart ->
    test.ok true

    pool.quit ->
      test.ok true
      test.done()

exports.testPoolIncrement = (test) ->
  test.expect 3

  pool = createPool config, size: 1
  test.same 1, pool.workers.length

  pool.increment()
  pool.increment()

  test.same 3, pool.workers.length

  pool.decrement()

  test.same 2, pool.workers.length

  test.done()

exports.testProxy = (test) ->
  test.expect 2

  pool = createPool config

  server = http.createServer (req, res) ->
    server.close()

    pool.proxy req, res, (err) ->
      test.ifError err

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
        pool.quit()
        test.done()
    req.end()

exports.testProxyRunOnce = (test) ->
  test.expect 9

  pool = createPool "#{__dirname}/fixtures/once.ru", runOnce: true
  test.ok pool.runOnce

  server = http.createServer (req, res) ->
    pool.proxy req, res, (err) ->
      test.ifError err

  request = (callback) ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 200, res.statusCode
      data = ""
      res.setEncoding 'utf8'
      res.on 'error', (err) -> test.ifError err
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
        test.same "true", data
        callback()
    req.end()

  server.listen 0
  server.on 'listening', ->
    async.series [request, request, request, request], ->
      server.close()
      pool.quit()
      test.done()

exports.testProxyRunOnceMultiple = (test) ->
  test.expect 9

  pool = createPool "#{__dirname}/fixtures/once.ru", runOnce: true, size: 2
  test.ok pool.runOnce

  server = http.createServer (req, res) ->
    pool.proxy req, res, (err) ->
      test.ifError err

  request = (callback) ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 200, res.statusCode
      data = ""
      res.setEncoding 'utf8'
      res.on 'error', (err) -> test.ifError err
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', ->
        test.same "true", data
        callback()
    req.end()

  server.listen 0
  server.on 'listening', ->
    async.parallel [request, request, request, request], ->
      server.close()
      pool.quit()
      test.done()

exports.testProxyWithClientException = (test) ->
  test.expect 2

  pool = createPool "#{__dirname}/fixtures/error.ru"

  server = http.createServer (req, res) ->
    server.close()

    pool.proxy req, res, (err) ->
      test.ok err
      res.writeHead 500
      res.end()
      pool.quit()

  server.listen 0
  server.on 'listening', ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 500, res.statusCode
      test.done()
    req.end()

exports.testErrorCreatingPool = (test) ->
  test.expect 2

  pool = createPool "#{__dirname}/fixtures/crash.ru", size: 1

  pool.on 'worker:error', (process, error) ->
    test.same "b00m", error.message

  pool.on 'exit', ->
    test.ok true
    test.done()

  pool.spawn()

exports.testErrorCreatingProcessOnProxy = (test) ->
  test.expect 3

  count = 3
  done = ->
    if --count is 0
      test.done()

  pool = createPool "#{__dirname}/fixtures/crash.ru", size: 1

  pool.on 'exit', ->
    test.ok true
    done()

  server = http.createServer (req, res) ->
    server.close()

    pool.proxy req, res, (err) ->
      test.ok err
      res.writeHead 500
      res.end()
      pool.quit()
      done()

  server.listen 0
  server.on 'listening', ->
    req = http.request host: '127.0.0.1', port: server.address().port, (res) ->
      test.same 500, res.statusCode
      done()
    req.end()

exports.testTerminate = (test) ->
  test.expect 3

  pool = createPool config, size: 2

  pool.once 'ready', ->
    test.ok true
    pool.terminate ->
      test.ok true
      test.done()

  pool.on 'error', (error) ->
    test.ifError error

  pool.once 'exit', ->
    test.ok true

  pool.spawn()

exports.testQuit = (test) ->
  test.expect 3

  pool = createPool config, size: 2

  pool.once 'ready', ->
    test.ok true
    pool.quit ->
      test.ok true
      test.done()

  pool.on 'error', (error) ->
    test.ifError error

  pool.once 'exit', ->
    test.ok true

  pool.spawn()
