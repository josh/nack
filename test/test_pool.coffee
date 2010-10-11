http = require 'http'

{createPool} = require 'nack/pool'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

exports.testCreatePoolEvents = (test) ->
  test.expect 5

  pool = createPool config, size: 3
  test.same 3, pool.workers.length
  test.same 0, pool.getReadyWorkerCount()

  pool.onNext 'ready', ->
    test.ok pool.getReadyWorkerCount() > 0

  pool.on 'worker:ready', ->
    if pool.getReadyWorkerCount() == 3
      pool.quit()

  pool.on 'exit', ->
    test.same 3, pool.workers.length
    test.same 0, pool.getReadyWorkerCount()
    test.done()

  pool.spawn()

exports.testCreatePoolWorkerEvents = (test) ->
  test.expect 4

  count = 0

  pool = createPool config, size: 3
  test.same 3, pool.workers.length
  test.same 0, pool.getReadyWorkerCount()

  pool.on 'worker:ready', ->
    count++

    if pool.getReadyWorkerCount() == 3
      test.same 3, pool.workers.length
      pool.quit()

  pool.on 'worker:exit', ->
    count--

    if count is 0
      test.same 0, pool.getReadyWorkerCount()
      test.done()

  pool.spawn()

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

exports.testProxyRequest = (test) ->
  test.expect 6

  pool = createPool config

  pool.onNext 'ready', ->
    test.ok true

  pool.on 'exit', ->
    test.ok true
    test.done()

  server = http.createServer (req, res) ->
    pool.onNext 'worker:busy', ->
      test.ok true

    pool.onNext 'worker:ready', ->
      test.ok true

    pool.proxyRequest req, res, ->
      test.ok true
      pool.quit()

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok !err
      server.close()
