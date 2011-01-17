{createServer} = require 'connect'
{createPool}   = require './pool'
{dirname}      = require 'path'

# Creates a [Connect](http://senchalabs.github.com/connect/)
# compatible server.
#
# You can use it similar to **http.createServer**
#
#     var server = nack.createServer("/path/to/app/config.ru");
#     server.listen(3000);
#
# Or with **Connect** middleware
#
#     var connect = require('connect');
#     var server = connect.createServer(
#       connect.logger(),
#       nack.createServer("/path/to/app/config.ru"),
#       connect.errorHandler({ dumpExceptions: true })
#     );
#
exports.createServer = (config, options) ->
  options ?= {}
  options.size ?= 3
  options.idle ?= 15 * 60 * 1000
  options.cwd  ?= dirname(config)

  pool = createPool config, options

  server = createServer (req, res, next) ->
    pool.proxyRequest req, res, req.proxyMetaVariables, (err) ->
      if err
        next err

  pool.on 'error', (error) ->
    server.emit 'error', error

  # DEPRECATED
  server.pool = pool

  server.stdout = pool.stdout
  server.stderr = pool.stderr

  origClose = server.close
  server.close = ->
    try
      origClose.apply this
    catch error
      if error.message is "Not running"
        @emit 'close'
      else
        throw error

  server.on 'close', ->
    pool.quit()

  server.restart = (callback) ->
    if pool.getAliveWorkerCount() is 0
      callback() if callback?
    else
      pool.once 'worker:ready', -> callback() if callback?
      pool.restart()

  server
