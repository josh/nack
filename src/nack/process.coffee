sys     = require 'sys'
client  = require 'nack/client'
{spawn} = require 'child_process'

tmpSock = () ->
  pid  = process.pid
  rand = Math.floor Math.random() * 10000000000
  "/tmp/nack." + pid + "." + rand + ".sock"

class Process
  constructor: (config) ->
    @sock  = tmpSock()
    @child = spawn "nackup", ['--file', @sock, config]

    @child.stdout.on 'data', (data) ->
      sys.log config + ': ' + data

    @child.stderr.on 'data', (data) ->
      sys.log config + ': ' + data

    @child.on 'exit', (code, signal) =>
      @sock  = null
      @child = null
      @onexit() if @onexit

  proxyRequest: (req, res) ->
    sock = client.createConnection @sock
    sock.proxyRequest req, res

  quit: (callback) ->
    @child.kill 'SIGQUIT'
    @onexit = callback

exports.Process = Process

exports.createProcess = (config) ->
  new Process config
