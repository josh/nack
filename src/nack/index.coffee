{createProcess} = require './process'
{createPool}    = require './pool'
{logStream}     = require './logger'

# Connect API
module.exports = (config, options) ->
  options ?= {}
  options.size ?= 3
  pool = createPool config, options
  (req, res, next) ->
    pool.proxyRequest req, res, (err) ->
      if err
        next err

# Expose `createProcess`, `createPool`, and `logStream`
module.exports.createProcess = createProcess
module.exports.createPool    = createPool
module.exports.logStream     = logStream
