sys            = require 'sys'
client         = require 'nack/client'
{spawn}        = require 'child_process'
{EventEmitter} = require 'events'

tmpSock = () ->
  pid  = process.pid
  rand = Math.floor Math.random() * 10000000000
  "/tmp/nack." + pid + "." + rand + ".sock"

exports.Process = class Process extends EventEmitter
  constructor: (@config) ->
    @state = null

  spawn: ->
    return if @state

    @state = 'spawning'
    @sockPath = tmpSock()
    @child = spawn "nackup", ['--file', @sockPath, @config]

    log = (message) =>
      sys.log @config + ': ' + message

    @child.stdout.on 'data', (data) =>
      log data

    @child.stderr.on 'data',(data) =>
      if !@ready && data.toString() is "ready\n"
        @state = 'ready'
        @emit 'ready'
      else
        log data

    @child.on 'exit', (code, signal) =>
      @state = @sockPath = @child = null
      @emit 'exit'

  whenReady: (callback) ->
    if @child and @state is 'ready'
      callback()
    else
      @spawn()
      @on 'ready', callback

  proxyRequest: (req, res, callback) ->
    @whenReady () =>
      connection = client.createConnection @sockPath
      connection.proxyRequest req, res, callback

  quit: () ->
    @child.kill 'SIGQUIT'

exports.createProcess = (config) ->
  new Process config
