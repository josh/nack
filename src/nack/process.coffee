sys            = require 'sys'
client         = require 'nack/client'
{spawn}        = require 'child_process'

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

  spawn: ->
    return if @state

    @changeState 'spawning'

    @sockPath = tmpSock()
    @child = spawn "nackup", ['--file', @sockPath, @config]

    @stdout = @child.stdout
    @stderr = @child.stderr

    ready = =>
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
      @emit state

  onState: (state, callback) ->
    if @state == state
      callback()
    else
      @onNext state, callback

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
      @changeState 'busy'
      connection = client.createConnection @sockPath
      connection.proxyRequest reqBuf, res, =>
        callback() if callback
        @changeState 'ready'
      reqBuf.flush()

  quit: ->
    if @child
      @child.kill 'SIGQUIT'

exports.createProcess = (args...) ->
  new Process args...
