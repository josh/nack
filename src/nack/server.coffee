http = require 'http'

{createPool} = require './pool'

exports.createServer = (config, options) ->
  options ?= {}
  options.size ?= 3
  options.idle ?= 15 * 60 * 1000

  pool = createPool config, options

  server = http.createServer (req, res, next) ->
    pool.proxyRequest req, res, (err) ->
      if err
        if next?
          next err
        else
          throw err

  server.pool = pool

  server
