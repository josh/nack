sys = require 'sys'

{BufferedLineStream} = require 'nack/buffered'

chomp = (str) ->
  str.replace /(\n|\r)+$/, ''

exports.Logger = class Logger
  constructor: (stream, log) ->
    stream = new BufferedLineStream stream
    log ?= sys.log

    stream.on 'data', (line) ->
      log chomp(line)

exports.logStream = (stream) ->
  new Logger stream
