{createPool} = require 'nack/pool'

config = __dirname + "/fixtures/hello.ru"

exports.testCreatePool = (test) ->
  test.expect 7

  pool = createPool config, size: 3
  test.same 3, pool.size
  test.same 3, pool.workers.length

  pool.spawn()

  pool.on 'ready', () ->
    test.ok pool.readyWorkers > 0

  pool.on 'worker:ready', () ->
    test.ok pool.readyWorkers > 0

    if pool.readyWorkers == 3
      pool.quit()

  pool.on 'exit', () ->
    test.same 0, pool.readyWorkers
    test.done()

exports.testPoolIncrement = (test) ->
  test.expect 6

  pool = createPool config, size: 3
  test.same 3, pool.size
  test.same 3, pool.workers.length

  pool.increment()
  pool.increment()

  test.same 5, pool.size
  test.same 5, pool.workers.length

  pool.decrement()

  test.same 4, pool.size
  test.same 4, pool.workers.length

  test.done()
