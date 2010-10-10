sys = require 'sys'

{BufferedLineStream} = require './buffered'

# Eat new lines, nom nom nom!
chomp = (str) ->
  str.replace /(\n|\r)+$/, ''

# **Logger** wraps a readable stream and logs it to stdout.
#
# Not sure if this belongs in nack, may eventually go away.
exports.Logger = class Logger
  constructor: (stream, log) ->
    stream = new BufferedLineStream stream
    log ?= sys.log

    stream.on 'data', (line) ->
      log chomp(line)

# Expose `Logger` helper method
exports.logStream = (stream) ->
  new Logger stream
