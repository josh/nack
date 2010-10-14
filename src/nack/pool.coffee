{EventEmitter}  = require 'events'
{createProcess} = require './process'

{BufferedReadStream} = require './buffered'

# A **Pool** manages multiple Ruby worker process.
#
# A Pool requires a path to a rackup file _(config.ru)_.
#
#     pool.createPool("/path/to/app/config.ru");
#
# Like Process, you can pass in an idle time in ms.
#
# You can a also set the max number of workers to spawn.
#
#     pool.createPool("/path/to/app/config.ru", { size: 5 });
#
# A Pool is an EventEmitter with the following events:
#
# > **Event 'worker:ready'**
# >
# > `function (process) { }`
# >
# >  Emitted when a worker process is 'ready'.
# >
# > **Event 'worker:spawn'**
# >
# > `function (process) { }`
# >
# > Emitted when a worker process has spawned.
# >
# > **Event 'worker:busy'**
# >
# > `function (process) { }`
# >
# > Emitted when a worker process becomes busy.
# >
# > **Event 'worker:exit'**
# >
# > `function (process) { }`
# >
# > Emitted when a worker process exitss
# >
# > **Event 'ready'**
# >
# > `function () { }`
# >
# > Emitted when at least one worker in the pool is ready.
# >
# > **Event 'exit'**
# >
# > `function () { }`
# >
# > Emitted when all the workers in the pool have exited.
#
exports.Pool = class Pool extends EventEmitter
  constructor: (@config, options) ->
    options ?= {}
    options.size ?= 1

    @workers = []
    @idle = options.idle

    # Initialize aggregate streams
    @stdout = new AggregateStream
    @stderr = new AggregateStream

    # When a worker becomes ready, check if the ready worker count moved
    # from 0 to 1
    previousReadyWorkerCount = 0
    @on 'worker:ready', () =>
      newReadyWorkerCount = @getReadyWorkerCount()
      if previousReadyWorkerCount is 0 and newReadyWorkerCount > 0
        @emit 'ready'
      previousReadyWorkerCount = newReadyWorkerCount

    # When a worker exists, check if the alive worker count goes down to 0
    @on 'worker:exit', () =>
      if @getAliveWorkerCount() is 0
        @emit 'exit'

    # Add `options.size` workers to the pool
    for n in [1..options.size]
      @increment()

  # Register a callback to only run once on the next event.
  onNext: (event, listener) ->
    callback = (args...) =>
      @removeListener event, callback
      listener args...
    @on event, callback

  # Get number of workers whose state is not null
  getAliveWorkerCount: () ->
    count = 0
    for worker in @workers when worker.state
      count++
    count

  # Get number of workers whose state is 'ready'
  getReadyWorkerCount: () ->
    count = 0
    for worker in @workers when worker.state is 'ready'
      count++
    count

  # Add a process to the pool
  increment: ->
    # Create a new process
    process = createProcess @config, idle: @idle

    # Push it onto the workers list
    @workers.push process

    process.on 'spawn', =>
      # Add the processes stdout and stderr to aggregate streams
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

  # Remove a process from the pool
  decrement: ->
    # Remove a process from the worker list
    if worker = @workers.shift()
      # and tell it to quit
      worker.quit()

  # Tell workers to announce their state if they're ready
  announceReadyWorkers: ->
    # Flag to see if we have at least one worker ready
    oneReady = false
    for worker in @workers
      # If a worker is ready, reemit 'worker:ready'
      if worker.state is 'ready'
        oneReady = true
        process.nextTick =>
          @emit 'worker:ready', worker
      # We have no ready workers yet and this worker hasn't started
      else if oneReady is false and !worker.state
        oneReady = true
        # Tell them to wake up!
        process.nextTick -> worker.spawn()

  # Eager spawn all the workers in the pool
  spawn: ->
    for worker in @workers
      worker.spawn()

  # Tell everyone to terminate
  terminate: ->
    for worker in @workers
      worker.terminate()

  # Tell everyone to die
  quit: ->
    for worker in @workers
      worker.quit()

  # Proxies `http.ServerRequest` and `http.ServerResponse` to a worker.
  proxyRequest: (req, res, callback) ->
    # Wrap the `http.ServerRequest` with a `BufferedReadStream`
    # so we don't miss any `data` or `end` events.
    reqBuf = new BufferedReadStream req

    # Wait for a ready worker
    @onNext 'worker:ready', (worker) ->
      worker.createConnection (connection) ->
        connection.proxyRequest reqBuf, res

        if callback
          connection.on 'error', callback
          connection.on 'close', callback

        # Flush any events captured while we were establishing
        # our client connection
        reqBuf.flush()

    # Tell any available workers to announce their state
    @announceReadyWorkers()

# Public API for creating a **Pool*
exports.createPool = (args...) ->
  new Pool args...

# **AggregateStream** takes multiple read stream and aggregates them into a
# single stream to listen on. Its used to aggregate all the workers stdout and
# stderr into one pool stdout and stderr streams.
class AggregateStream extends EventEmitter
  # Register a new stream and process
  add: (stream, process) ->
    stream.on 'data', (data) =>
      @emit 'data', data, process

    stream.on 'error', (exception) =>
      @emit 'error', exception, process

    stream.on 'end', =>
      @emit 'end', process

    stream.on 'close', =>
      @emit 'close', process
