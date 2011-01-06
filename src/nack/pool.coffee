{EventEmitter}      = require 'events'
{createProcess}     = require './process'
{pause, isFunction} = require './util'

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

    @processOptions =
      idle:  options.idle
      debug: options.debug
      cwd:   options.cwd

    # Initialize aggregate streams
    @stdout = new AggregateStream
    @stderr = new AggregateStream

    self = this

    # When a worker becomes ready, check if the ready worker count moved
    # from 0 to 1
    previousReadyWorkerCount = 0
    @on 'worker:ready', () ->
      newReadyWorkerCount = self.getReadyWorkerCount()
      if previousReadyWorkerCount is 0 and newReadyWorkerCount > 0
        self.emit 'ready'
      previousReadyWorkerCount = newReadyWorkerCount

    # When a worker exists, check if the alive worker count goes down to 0
    @on 'worker:exit', () ->
      if self.getAliveWorkerCount() is 0
        self.emit 'exit'

    # Add `options.size` workers to the pool
    for n in [1..options.size]
      @increment()

  # Register a callback to only run once on the next event.
  onNext: (event, listener) ->
    self = this
    callback = (args...) ->
      self.removeListener event, callback
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
    process = createProcess @config, @processOptions

    # Push it onto the workers list
    @workers.push process

    self = this

    process.on 'spawn', ->
      # Add the processes stdout and stderr to aggregate streams
      self.stdout.add process.stdout, process
      self.stderr.add process.stderr, process
      self.emit 'worker:spawn', process

    process.on 'ready', ->
      self.emit 'worker:ready', process

    process.on 'busy', ->
      self.emit 'worker:busy', process

    process.on 'exit', ->
      self.emit 'worker:exit', process

    process

  # Remove a process from the pool
  decrement: ->
    # Remove a process from the worker list
    if worker = @workers.shift()
      # and tell it to quit
      worker.quit()

  # Tell workers to announce their state if they're ready
  announceReadyWorkers: ->
    self = this
    # Flag to see if we have at least one worker ready
    oneReady = false
    for worker in @workers
      # If a worker is ready, reemit 'worker:ready'
      if worker.state is 'ready'
        oneReady = true
        process.nextTick ->
          self.emit 'worker:ready', worker
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
  proxyRequest: (req, res, args...) ->
    if isFunction args[0]
      callback = args[0]
    else
      metaVariables = args[0]
      callback = args[1]

    # Pause request so we don't miss any `data` or `end` events.
    resume = pause req

    # Wait for a ready worker
    @onNext 'worker:ready', (worker) ->
      worker.createConnection (connection) ->
        connection.proxyRequest req, res, metaVariables

        if callback
          connection.on 'error', callback
          connection.on 'close', callback

        # Flush any events captured while we were establishing
        # our client connection
        resume()

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
    self = this

    stream.on 'data', (data) ->
      self.emit 'data', data, process

    stream.on 'error', (exception) ->
      self.emit 'error', exception, process
