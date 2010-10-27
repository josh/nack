{EventEmitter} = require 'events'

# **BufferedLineStream** wraps any readable stream and buffers data until
# it encounters a `\n` line break. It will emit `data` events as lines
# instead of arbitrarily chunked text.
#
#     stdoutLines = new BufferedLineStream(stdoutStream)
#     stdoutLines.on 'data', (line) ->
#       if line.match "TO: "
#         console.log line
#
exports.BufferedLineStream = class BufferedLineStream extends EventEmitter
  constructor: (@stream) ->
    @readable = true
    @_buffer = ""
    @_flushed = false

    # Buffer `data` and `end` events from `@stream`
    @stream.on 'data',  (args...) => @write args...
    @stream.on 'end',   (args...) => @end args...

    # Forward `error`, `close` and `fd` events from `@stream`
    @stream.on 'error', (args...) => @emit 'error', args...
    @stream.on 'close', (args...) => @emit 'close', args...
    @stream.on 'fd',    (args...) => @emit 'fd', args...

    # Forward any properties to `@stream`
    for all name, fun of @stream when !this[name] and name[0] != '_'
      @__defineGetter__ name, (args...) -> @stream[name]

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
