{createPool} = require 'nack/pool'

config = __dirname + "/fixtures/hello.ru"

exports.testCreatePool = (test) ->
  test.expect 10

  pool = createPool config, size: 3
  test.same 3, pool.size
  test.same 3, pool.workers.length

  pool.spawn()

  pool.onNext 'ready', () ->
    test.same 1, pool.readyWorkers

  pool.onNext 'worker:ready', () ->
    test.same 1, pool.readyWorkers

    pool.onNext 'worker:ready', () ->
      test.same 2, pool.readyWorkers

      pool.onNext 'worker:ready', () ->
        test.same 3, pool.readyWorkers

  pool.on 'worker:ready', () ->
    if pool.readyWorkers == 3
      pool.quit()

  pool.onNext 'worker:exit', () ->
    test.same 2, pool.readyWorkers

    pool.onNext 'worker:exit', () ->
      test.same 1, pool.readyWorkers

      pool.onNext 'worker:exit', () ->
        test.same 0, pool.readyWorkers
        test.done()

  pool.onNext 'exit', () ->
    test.same 0, pool.readyWorkers

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
