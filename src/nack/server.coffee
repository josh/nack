{createServer} = require 'connect'
{createPool}   = require './pool'

exports.createServer = (config, options) ->
  options ?= {}
  options.size ?= 3
  options.idle ?= 15 * 60 * 1000

  pool = createPool config, options

  server = createServer (req, res, next) ->
    pool.proxyRequest req, res, (err) ->
      if err
        next err

  server.on 'close', ->
    pool.quit()

  server.pool = pool

  server
