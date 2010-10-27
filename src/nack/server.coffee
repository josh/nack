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
    pool.proxyRequest req, res, (err) ->
      if err
        next err

  server.on 'close', ->
    pool.terminate()

  server.pool = pool

  server
