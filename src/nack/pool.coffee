{EventEmitter}  = require 'events'
{createProcess} = require 'nack/process'

class AggregateStream extends EventEmitter
  add: (stream, process) ->
    stream.on 'data', (data) =>
      @emit 'data', data, process

    stream.on 'error', (exception) =>
      @emit 'error', exception, process

    stream.on 'end', () =>
      @emit 'end', process

    stream.on 'close', () =>
      @emit 'close', process

exports.Pool = class Pool extends EventEmitter
  constructor: (@config, size) ->
    @size         = 0
    @workers      = []
    @readyWorkers = 0

    @stdout = new AggregateStream
    @stderr = new AggregateStream

    for n in [1..size]
      @increment()

    @on 'worker:ready', () =>
      @readyWorkers++
      if @readyWorkers is 1
        @emit 'ready'
      if @readyWorkers is @size
        @emit 'allready'

    @on 'worker:exit', () =>
      @readyWorkers-- if @readyWorkers > 0
      if @readyWorkers is 0
        @emit 'exit'

  increment: () ->
    @size++

    process = createProcess @config

    process.on 'ready', () =>
      @emit 'worker:ready'

    process.on 'exit', () =>
      @emit 'worker:exit'

    @workers.push process
    process

  decrement: () ->
    @size--
    @workers.shift()

  spawn: () ->
    for worker in @workers
      worker.spawn()

      @stdout.add worker.stdout, worker
      @stderr.add worker.stderr, worker

  proxyRequest: (req, res, callback) ->
    worker = @workers.shift()
    worker.proxyRequest req, res, () =>
      callback() if callback?
      @workers.push worker

  quit: () ->
    for worker in @workers
      worker.quit()

exports.createPool = (args...) ->
  new Pool args...
