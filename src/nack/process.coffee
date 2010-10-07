sys           = require 'sys'
client        = require 'nack/client'
{spawn, exec} = require 'child_process'
{exists}      = require 'path'

{EventEmitter} = require 'events'
{BufferedReadStream, BufferedLineStream} = require 'nack/buffered'

tmpSock = ->
  pid  = process.pid
  rand = Math.floor Math.random() * 10000000000
  "/tmp/nack." + pid + "." + rand + ".sock"

exports.Process = class Process extends EventEmitter
  constructor: (@config, options) ->
    options ?= {}
    @idle  = options.idle
    @state = null

    raiseConfigError = =>
      @emit 'error', new Error "configuration \"#{@config}\" doesn't exist"

    if @config?
      exists @config, (ok) =>
        raiseConfigError() if !ok
    else
      raiseConfigError()

    @on 'busy', =>
      @deferTimeout()

  getNackupPath: (callback) ->
    if @nackupPath?
      callback null, @nackupPath
    else
      exec 'which nackup', (error, stdout, stderr) =>
        if error
          callback new Error "Couldn't find `nackup` in PATH"
        else
          @nackupPath = stdout.replace /(\n|\r)+$/, ''
          callback error, @nackupPath

  spawn: () ->
    return if @state

    @changeState 'spawning'

    @getNackupPath (err, nackup) =>
      return @emit 'error', err if err

      @sockPath = tmpSock()
      @child = spawn "nackup", ['--file', @sockPath, @config]

      @stdout = @child.stdout
      @stderr = @child.stderr

      readyLineHandler = (line) =>
        if line.toString() is "ready"
          @stdout.removeListener 'data', readyLineHandler
          @changeState 'ready'
      stdoutLines = new BufferedLineStream @stdout
      stdoutLines.on 'data', readyLineHandler

      @child.on 'exit', (code, signal) =>
        @clearTimeout()
        @state = @sockPath = @child = null
        @stdout = @stderr = null
        @emit 'exit'

      @emit 'spawn'

    this

  onNext: (event, listener) ->
    callback = (args...) =>
      @removeListener event, callback
      listener args...
    @on event, callback

  changeState: (state) ->
    if @state != state
      @state = state
      process.nextTick => @emit state

  onState: (state, callback) ->
    if @state == state
      callback()
    else
      @onNext state, =>
        @onState state, callback

  clearTimeout: ->
    if @_timeoutId
      clearTimeout @_timeoutId

  deferTimeout: ->
    if @idle
      @clearTimeout()

      callback = =>
        @emit 'idle'
        @quit()
      @_timeoutId = setTimeout callback, @idle

  createConnection: (callback) ->
    @spawn()

    @onState 'ready', =>
      @changeState 'busy'

      connection = client.createConnection @sockPath

      connection.on 'close', () =>
        @changeState 'ready'

      callback connection

  proxyRequest: (req, res, callback) ->
    reqBuf = new BufferedReadStream req

    @createConnection (connection) ->
      connection.proxyRequest reqBuf, res

      if callback
        connection.on 'error', callback
        connection.on 'close', callback

      reqBuf.flush()

  kill: ->
    if @child
      @changeState 'quitting'
      @child.kill 'SIGTERM'

  quit: ->
    if @child
      @changeState 'quitting'
      @child.kill 'SIGQUIT'

exports.createProcess = (args...) ->
  new Process args...
