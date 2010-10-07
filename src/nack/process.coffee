sys           = require 'sys'
client        = require 'nack/client'
{spawn, exec} = require 'child_process'
{exists}      = require 'path'

{EventEmitter}       = require 'events'
{BufferedReadStream} = require 'nack/buffered'

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

      ready = (data) =>
        if data.toString() is "ready\n"
          @stdout.removeListener 'data', ready
          @stderr.removeListener 'data', ready
          @changeState 'ready'

      @stdout.on 'data', ready
      @stderr.on 'data', ready

      @child.on 'exit', (code, signal) =>
        @clearTimeout()
        @state = @sockPath = @child = null
        @stdout = @stderr = null
        @emit 'exit'

      @on 'ready', =>
        @deferTimeout()

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

  proxyRequest: (req, res, callback) ->
    @deferTimeout()

    reqBuf = new BufferedReadStream req
    @spawn()

    @onState 'ready', =>
      if @state isnt 'ready'
        @emit 'error', new Error "process said it was ready but wasn't"

      @changeState 'busy'
      connection = client.createConnection @sockPath
      connection.proxyRequest reqBuf, res, (err) =>
        if err and callback
          callback err
        else if err
          @emit 'error', err

        callback() if callback
        @changeState 'ready'
      reqBuf.flush()

  quit: ->
    if @child
      @changeState 'quitting'
      @child.kill 'SIGQUIT'
    else
      process.nextTick => @emit 'exit'

exports.createProcess = (args...) ->
  new Process args...
