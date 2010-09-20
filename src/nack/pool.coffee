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
  constructor: (@config, options) ->
    options ?= {}

    @size         = 0
    @workers      = []
    @readyWorkers = 0

    @idle = options.idle

    @stdout = new AggregateStream
    @stderr = new AggregateStream

    for n in [1..options.size]
      @increment()

  onNext: (event, listener) ->
    callback = (args...) =>
      @removeListener event, callback
      listener args...
    @on event, callback

  increment: () ->
    @size++

    process = createProcess @config, idle: @idle

    process.on 'spawn', () =>
      @stdout.add process.stdout, process
      @stderr.add process.stderr, process

    process.on 'ready', () =>
      previousReadyWorkers = @readyWorkers
      @readyWorkers++

      if previousReadyWorkers is 0 and @readyWorkers is 1
        @emit 'ready'

      @emit 'worker:ready'

    process.on 'busy', () =>
      @readyWorkers-- if @readyWorkers > 0
      @emit 'worker:busy'

    process.on 'exit', () =>
      @readyWorkers-- if @readyWorkers > 0

      if @readyWorkers is 0
        @emit 'exit'

      @emit 'worker:exit'

    @workers.push process
    process

  decrement: () ->
    if worker = @workers.shift()
      @size--
      worker.quit()
      worker

  spawn: () ->
    for worker in @workers
      worker.spawn()

  quit: () ->
    true while @decrement()

  proxyRequest: (req, res, callback) ->
    worker = @workers.shift()
    worker.proxyRequest req, res, () =>
      callback() if callback?
      @workers.unshift worker

exports.createPool = (args...) ->
  new Pool args...
