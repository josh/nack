{createProcess} = require './process'
{createPool}    = require './pool'

# Connect API
module.exports = (config, options) ->
  options ?= {}
  options.size ?= 3
  pool = createPool config, options
  (req, res, next) ->
    pool.proxyRequest req, res, (err) ->
      if err
        next err

# Expose `createProcess` and `createPool`
module.exports.createProcess = createProcess
module.exports.createPool    = createPool
