{EventEmitter} = require 'events'

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

  stream.pause()
  stream.on 'data', (args...) -> queue.push ['data', args...]
  stream.on 'end',  (args...) -> queue.push ['end', args...]

  ->
    for args in queue
      stream.emit args...
    stream.resume()

# **LineBuffer** wraps any readable stream and buffers data until
# it encounters a `\n` line break. It will emit `data` events as lines
# instead of arbitrarily chunked text.
#
#     stdoutLines = new LineBuffer(stdoutStream)
#     stdoutLines.on 'data', (line) ->
#       if line.match "TO: "
#         console.log line
#
exports.LineBuffer = class LineBuffer extends EventEmitter
  constructor: (@stream) ->
    @readable = true
    @_buffer = ""

    # Buffer `data` and `end` events from `@stream`
    self = this
    @stream.on 'data', (args...) -> self.write args...
    @stream.on 'end',  (args...) -> self.end args...

  write: (chunk) ->
    # Write chunk to string buffer
    @_buffer += chunk

    # Check for `\n` in buffer
    while (index = @_buffer.indexOf("\n")) != -1
      line     = @_buffer[0...index]
      @_buffer = @_buffer[index+1...@_buffer.length]

      # Emit `data` line as a single line
      @emit 'data', line

  end: (args...) ->
    if args.length > 0
      @write args...

    @emit 'end'
