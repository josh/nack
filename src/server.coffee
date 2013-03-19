{createServer} = require 'http'
{createPool}   = require './pool'

# Creates a HTTP server.
#
# You can use it similar to **http.createServer**
#
#     var server = nack.createServer("/path/to/app/config.ru");
#     server.listen(3000);
#
exports.createServer = (config, options) ->
  options ?= {}
  options.size ?= 3
  options.idle ?= 15 * 60 * 1000

  pool = createPool config, options
  createServer pool.proxy
