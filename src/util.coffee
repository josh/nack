{Stream} = require 'stream'

if process.env.NODE_DEBUG and /nack/.test process.env.NODE_DEBUG
  exports.debug = (args...) -> console.error 'NACK:', args...
else
  exports.debug = ->

# Is a given value a function?
exports.isFunction = (obj) ->
  if obj and obj.constructor and obj.call and obj.apply then true else false

# Pauses Event Emitter
#
# Hack for http.ServerRequest#pause
#
# ry says it will be fixed soonish
exports.pause = (stream) ->
  queue = []

  onData  = (args...) -> queue.push ['data', args...]
  onEnd   = (args...) -> queue.push ['end', args...]
  onClose = -> removeListeners()

  removeListeners = ->
    stream.removeListener 'data', onData
    stream.removeListener 'end', onEnd
    stream.removeListener 'close', onClose

  stream.on 'data', onData
  stream.on 'end', onEnd
  stream.on 'close', onClose

  ->
    removeListeners()

    for args in queue
      stream.emit args...

# **LineBuffer** wraps any readable stream and buffers data until
# it encounters a `\n` line break. It will emit `data` events as lines
# instead of arbitrarily chunked text.
#
#     stdoutLines = new LineBuffer(stdoutStream)
#     stdoutLines.on 'data', (line) ->
#       if line.match "TO: "
#         console.log line
#
exports.LineBuffer = class LineBuffer extends Stream
  constructor: (@stream) ->
    @readable = true
    @_buffer = ""

    self = this
    @stream.on 'data', (args...) -> self.write args...
    @stream.on 'end',  (args...) -> self.end args...

  write: (chunk) ->
    @_buffer += chunk

    while (index = @_buffer.indexOf("\n")) != -1
      line     = @_buffer[0...index]
      @_buffer = @_buffer[index+1...@_buffer.length]

      # Emit `data` line as a single line
      @emit 'data', line

  end: (args...) ->
    if args.length > 0
      @write args...

    @emit 'end'
