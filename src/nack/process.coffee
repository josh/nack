sys     = require 'sys'
client  = require 'nack/client'
{spawn} = require 'child_process'

tmpSock = () ->
  pid  = process.pid
  rand = Math.floor Math.random() * 10000000000
  "/tmp/nack." + pid + "." + rand + ".sock"

exports.Process = class Process
  constructor: (@config) ->
    @state = null
    @listeners = {}

    @sock  = tmpSock()
    @child = spawn "nackup", ['--file', @sock, @config]

    log = (message) =>
      sys.log @config + ': ' + message

    setReady = () =>
      @state = 'ready'
      if onready = @listeners['ready']
        onready @

    @child.stdout.on 'data', (data) =>
      log data

    @child.stderr.on 'data',(data) =>
      if !@ready && data.toString() is "ready\n"
        setReady()
      else
        log data

    @child.on 'exit', (code, signal) =>
      @sock  = null
      @child = null

      if onexit = @listeners['exit']
        onexit()

  on: (event, callback) ->
    @listeners[event] = callback

  proxyRequest: (req, res) ->
    sock = client.createConnection @sock
    sock.proxyRequest req, res

  quit: () ->
    @child.kill 'SIGQUIT'

exports.createProcess = (config) ->
  new Process config
