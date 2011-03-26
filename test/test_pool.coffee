http = require 'http'

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
  test.expect 1

  pool = createPool config, size: 2

  pool.restart ->
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
    http.cat "http://127.0.0.1:#{server.address().port}/", "utf8", (err, data) ->
      test.ifError err
      test.same "Hello World\n", data

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
    http.cat "http://127.0.0.1:#{server.address().port}/", "utf8", (err, data) ->
      test.same 500, err
      test.done()

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
    http.cat "http://127.0.0.1:#{server.address().port}/", "utf8", (err, data) ->
      test.same 500, err
      done()
