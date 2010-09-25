{EventEmitter}  = require 'events'
{createProcess} = require 'nack/process'

{BufferedReadStream} = require 'nack/buffered'

removeFromArray = (array, obj) ->
  index = array.indexOf obj
  if index isnt -1
    array.splice index, 1

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

    @workers      = []
    @readyWorkers = []

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

  increment: ->
    process = createProcess @config, idle: @idle

    process.on 'spawn', =>
      @stdout.add process.stdout, process
      @stderr.add process.stderr, process

    process.on 'ready', =>
      previousCount = @readyWorkers.length
      @readyWorkers.push process

      @emit 'worker:ready', process

      if previousCount is 0 and @readyWorkers.length > 0
         @emit 'ready'

    process.on 'busy', =>
      removeFromArray @readyWorkers, process
      @emit 'worker:busy', process

    process.on 'exit', =>
      removeFromArray @workers, process
      removeFromArray @readyWorkers, process

      @emit 'worker:exit', process

      if @workers.length is 0
        @emit 'exit'

    @workers.push process
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
      worker.proxyRequest reqBuf, res, ->
        callback() if callback?
      reqBuf.flush()

    @announceReadyWorkers()

exports.createPool = (args...) ->
  new Pool args...
