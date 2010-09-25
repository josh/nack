http = require 'http'

{createPool} = require 'nack/pool'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

exports.testCreatePool = (test) ->
  test.expect 14

  count = 0

  pool = createPool config, size: 3
  test.same 3, pool.workers.length
  test.same 0, pool.readyWorkers.length

  pool.onNext 'ready', ->
    test.same 1, pool.readyWorkers.length

  pool.on 'worker:ready', ->
    count++
    test.same count, pool.readyWorkers.length

  pool.on 'worker:ready', ->
    if pool.readyWorkers.length == 3
      pool.quit()

  pool.on 'worker:exit', ->
    count--
    test.same count, pool.workers.length
    test.same count, pool.readyWorkers.length

  pool.onNext 'exit', ->
    test.same 0, pool.workers.length
    test.same 0, pool.readyWorkers.length
    test.done()

  pool.spawn()

exports.testPoolIncrement = (test) ->
  test.expect 4

  pool = createPool config, size: 1
  test.same 1, pool.workers.length

  pool.increment()
  pool.increment()

  test.same 3, pool.workers.length

  pool.decrement()

  test.same 2, pool.workers.length

  pool.on 'exit', ->
    test.same 0, pool.workers.length
    test.done()

  pool.quit()

exports.testProxyRequest = (test) ->
  test.expect 7

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

  server.on 'close', ->
    test.ok true

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok !err
      server.close()
