{EventEmitter}  = require 'events'
{createProcess} = require './process'

{BufferedReadStream} = require './buffered'

class AggregateStream extends EventEmitter
  add: (stream, process) ->
    stream.on 'data', (data) =>
      @emit 'data', data, process

    stream.on 'error', (exception) =>
      @emit 'error', exception, process

    stream.on 'end', =>
      @emit 'end', process

    stream.on 'close', =>
      @emit 'close', process

exports.Pool = class Pool extends EventEmitter
  constructor: (@config, options) ->
    options ?= {}
    options.size ?= 1

    @workers = []
    @idle = options.idle

    @stdout = new AggregateStream
    @stderr = new AggregateStream

    previousReadyWorkerCount = 0
    @on 'worker:ready', () =>
      newReadyWorkerCount = @getReadyWorkerCount()
      if previousReadyWorkerCount is 0 and newReadyWorkerCount > 0
        @emit 'ready'
      previousReadyWorkerCount = newReadyWorkerCount

    @on 'worker:exit', () =>
      if @getAliveWorkerCount() is 0
        @emit 'exit'

    for n in [1..options.size]
      @increment()

  onNext: (event, listener) ->
    callback = (args...) =>
      @removeListener event, callback
      listener args...
    @on event, callback

  getAliveWorkerCount: () ->
    count = 0
    for worker in @workers when worker.state
      count++
    count

  getReadyWorkerCount: () ->
    count = 0
    for worker in @workers when worker.state is 'ready'
      count++
    count

  increment: ->
    process = createProcess @config, idle: @idle
    @workers.push process

    process.on 'spawn', =>
      @stdout.add process.stdout, process
      @stderr.add process.stderr, process
      @emit 'worker:spawn', process

    process.on 'ready', =>
      @emit 'worker:ready', process

    process.on 'busy', =>
      @emit 'worker:busy', process

    process.on 'exit', =>
      @emit 'worker:exit', process

    process

  decrement: ->
    if worker = @workers.shift()
      worker.quit()

  announceReadyWorkers: ->
    oneReady = false
    for worker in @workers
      if worker.state is 'ready'
        oneReady = true
        process.nextTick =>
          @emit 'worker:ready', worker
      else if oneReady is false and !worker.state
        oneReady = true
        process.nextTick -> worker.spawn()

  spawn: ->
    for worker in @workers
      worker.spawn()

  quit: ->
    for worker in @workers
      worker.quit()

  proxyRequest: (req, res, callback) ->
    reqBuf = new BufferedReadStream req

    @onNext 'worker:ready', (worker) ->
      worker.createConnection (connection) ->
        connection.proxyRequest reqBuf, res

        if callback
          connection.on 'error', callback
          connection.on 'close', callback

        reqBuf.flush()

    @announceReadyWorkers()

exports.createPool = (args...) ->
  new Pool args...
