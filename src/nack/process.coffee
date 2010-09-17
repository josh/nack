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

  spawn: ->
    return if @child

    @sockPath = tmpSock()
    @child = spawn "nackup", ['--file', @sockPath, @config]

    log = (message) =>
      sys.log @config + ': ' + message

    @child.stdout.on 'data', (data) =>
      log data

    @child.stderr.on 'data',(data) =>
      if !@ready && data.toString() is "ready\n"
        @emit 'ready'
      else
        log data

    @child.on 'exit', (code, signal) =>
      @sockPath = @child = null
      @emit 'exit'

  proxyRequest: (req, res) ->
    connection = client.createConnection @sockPath
    connection.proxyRequest req, res

  quit: () ->
    @child.kill 'SIGQUIT'

exports.createProcess = (config) ->
  new Process config
