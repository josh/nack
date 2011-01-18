client              = require './client'
fs                  = require 'fs'
{exists}            = require 'path'
{pause, isFunction} = require './util'
{LineBuffer}        = require './util'
{spawn, exec}       = require 'child_process'
{EventEmitter}      = require 'events'

packageBin = fs.realpathSync "#{__dirname}/../../bin"
packageLib = fs.realpathSync "#{__dirname}/.."

# **Process** manages a single Ruby worker process.
#
# A Process requires a path to a rackup config file _(config.ru)_.
#
#     process.createProcess("/path/to/app/config.ru");
#
# You can set a idle time so the process dies after a
# specified amount of milliseconds.
#
#     var ms = 15 * 60 * 1000;
#     process.createProcess("/path/to/app/config.ru", { idle: ms });
#
# A Process has 5 states:
#
# > `null`: Not started or dead
# >
# > `spawning`: Is booting and can't accept a connection yet
# >
# > `ready`: Is ready to accept a connection and handle a request
# >
# > `busy`: Is currently handling a request, not ready
# >
# > `quitting`: Was set a kill signal and is shutting down
#
# Anytime a process changes states, an event is fired with the new
# state name. When the process becomes `ready`, a `ready` is fired.
#
# Other events:
#
# > **Event: 'error'**
# >
# > `function (exception) { }`
# >
# > Emitted when an error occurs.
# >
# > **Event: 'spawn'**
# >
# > `function (exception) { }`
# >
# > Emitted when the process moves from `spawning` to `ready` state.
# >
# > **Event: 'exit'**
# >
# > `function () { }`
# >
# > Emitted when the Process terminates.
# >
# > **Event: 'idle'**
# >
# > `function () { }`
# >
# > Emitted when the Process times out because of inactivity.
#
exports.Process = class Process extends EventEmitter
  constructor: (@config, options) ->
    self = @

    options ?= {}
    @idle  = options.idle
    @cwd   = options.cwd
    @env   = options.env ? {}

    # Set initial state to `null`
    @state = null

    @_connectionQueue = []
    @_activeConnection = null

    raiseConfigError = ->
      self.emit 'error', new Error "configuration \"#{@config}\" doesn't exist"

    # Raise an exception unless `config` exists
    if @config?
      exists @config, (ok) ->
        raiseConfigError() if !ok
    else
      raiseConfigError()

    @on 'ready', ->
      self._processConnections()

    @on 'error', (error) ->
      callback = self._activeConnection
      self._activeConnection = null

      if callback
        callback error
      else if self.listeners('error').length <= 1
        throw error

    # Push back the idle time everytime a request is handled
    @on 'busy', ->
      self.deferTimeout()

  spawn: ->
    # Do nothing if the process is already started
    return if @state

    # Change start to `spawning` and fire an event
    @changeState 'spawning'

    # Generate a random sock path
    tmp = tmpFile()
    @sockPath = "#{tmp}.sock"
    @pipePath = "#{tmp}.pipe"

    # Copy process environment
    env = {}
    for key, value of process.env
      env[key] = value

    for key, value of @env
      env[key] = value

    env['PATH']    = "#{packageBin}:#{env['PATH']}"
    env['RUBYLIB'] = "#{packageLib}:#{env['RUBYLIB']}"

    createPipeStream @pipePath, (err, pipe) =>
      return @emit 'error', err if err

      args = [@config, @sockPath, @pipePath]

      # Spawn a Ruby server connecting to our `@sockPath`
      @child = spawn "nack_worker", args,
        cwd: @cwd
        env: env

      # Expose `stdout` and `stderr` on Process
      @stdout = @child.stdout
      @stderr = @child.stderr

      pipeError = null

      pipe.on 'data', (data) =>
        if !@child or !@child.pid or data.toString() isnt @child.pid.toString()
          try
            exception       = JSON.parse data
            pipeError       = new Error exception.message
            pipeError.name  = exception.name
            pipeError.stack = exception.stack
          catch e
            pipeError = new Error "unknown spawn error"

      pipe.on 'end', =>
        pipe = null
        unless pipeError
          @pipe = fs.createWriteStream @pipePath
          @pipe.on 'open', => @changeState 'ready'

      # When the child process exists, clear out state and
      # emit `exit`
      @child.on 'exit', (code, signal) =>
        @clearTimeout()
        @pipe.end() if @pipe

        @state = @sockPath = @pipePath = null
        @child = @pipe = null
        @stdout = @stderr = null

        if code isnt 0 and pipeError
          @emit 'error', pipeError

        @_connectionQueue = []
        @_activeConnection = null

        @emit 'exit'

      @emit 'spawn'

    @

  if not EventEmitter.prototype.once
    once: (event, listener) ->
      self = this
      callback = (args...) ->
        self.removeListener event, callback
        listener args...
      @on event, callback

  # Change the current state and fire a corresponding event
  changeState: (state) ->
    self = this
    if @state != state
      @state = state
      # State change events are always asynchronous
      process.nextTick -> self.emit state

  # Clear current timeout handler.
  clearTimeout: ->
    if @_timeoutId
      clearTimeout @_timeoutId

  # Defer the current idle timer.
  deferTimeout: ->
    self = this
    if @idle
      # Clear the current timer
      @clearTimeout()

      callback = ->
        self.emit 'idle'
        self.quit()

      # Register a new timer
      @_timeoutId = setTimeout callback, @idle

  _processConnections: ->
    self = @

    unless @_activeConnection
      @_activeConnection = @_connectionQueue.shift()

    if @_activeConnection and @state is 'ready'
      # Immediately flag process as `busy`
      @changeState 'busy'

      # Create a connection to our sock path
      connection = client.createConnection @sockPath

      # When the connection closes, change the state back to ready.
      connection.on 'close', ->
        self._activeConnection = null
        self.changeState 'ready'

      @_activeConnection null, connection
    else
      @spawn()

  # Create a new **Client** connection
  createConnection: (callback) ->
    @_connectionQueue.push callback
    @_processConnections()
    @

  # Proxies a `http.ServerRequest` and `http.ServerResponse` to the process
  proxyRequest: (req, res, args...) ->
    self = this

    if isFunction args[0]
      callback = args[0]
    else
      metaVariables = args[0]
      callback = args[1]

    # Pause request so we don't miss any `data` or `end` events.
    resume = pause req

    @createConnection (err, connection) ->
      if err
        if callback then callback err
        else self.emit 'error', err
      else
        if callback
          connection.on 'close', callback
          connection.on 'error', (error) ->
            connection.removeListener 'close', callback
            callback error

        connection.proxyRequest req, res, metaVariables

      # Flush any events captured while we were establishing
      # our client connection
      resume()

  # Send `SIGKILL` to process.
  # This will kill it for sure.
  kill: ->
    if @child
      @changeState 'quitting'
      @child.kill 'SIGKILL'

  # Send `SIGTERM` to process.
  # This will immediately kill it.
  terminate: ->
    if @child
      @changeState 'quitting'
      @child.kill 'SIGTERM'

      timeout = setTimeout =>
        if @state is 'quitting'
          @kill()
      , 1000
      @once 'exit', -> clearTimeout timeout

  # Send `SIGTERM` to process.
  # The process will finish serving its request and gracefully quit.
  quit: ->
    if @child
      @changeState 'quitting'
      @child.kill 'SIGQUIT'

      timeout = setTimeout =>
        if @state is 'quitting'
          @terminate()
      , 1000
      @once 'exit', -> clearTimeout timeout

  # Quit and respawn process
  restart: ->
    @once 'exit', => @spawn()
    @quit()

# Public API for creating a **Process**
exports.createProcess = (args...) ->
  new Process args...

# Generates a random path.
tmpFile = ->
  pid  = process.pid
  rand = Math.floor Math.random() * 10000000000
  "/tmp/nack." + pid + "." + rand

createPipeStream = (path, callback) ->
  exec "mkfifo #{path}", (error, stdout, stderr) ->
    if error?
      callback error
    else
      stream = fs.createReadStream path
      callback null, stream
