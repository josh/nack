{EventEmitter} = require 'events'

# **BufferedReadStream** wraps any readable stream and captures any events
# it fires. The events are held in a buffer until `flush` is called.
#
#     http.createServer (req, res) ->
#       bufferedReq = new BufferedReadStream req
#       fs.readFile path, () ->
#         bufferedReq.on 'data' (chunk) ->
#           console.log
#
exports.BufferedReadStream = class BufferedReadStream extends EventEmitter
  constructor: (@stream) ->
    @readable = true
    @_queue = []
    @_flushed = false

    queueEvent = (event, args...) =>
      if @_flushed
        @emit event, args...
      else
        @_queue.push ['emit', event, args...]

    # Listen and queue up any events on the `@stream`
    @stream.on 'data',  (args...) -> queueEvent 'data', args...
    @stream.on 'end',   (args...) -> queueEvent 'end', args...
    @stream.on 'error', (args...) -> queueEvent 'error', args...

    # Tell the `@stream` to pause and stop emitting new events
    @stream.pause()

    # Forward any properties to `@stream`
    for all name, fun of @stream when !this[name] and name[0] != '_'
      @__defineGetter__ name, (args...) -> @stream[name]

  # Ignore requests to resume the stream
  resume: ->

  # Ignore requrests to pause the stream
  pause: ->

  # Destroy `@stream` and clear queue
  destroy: ->
    @_queue = []
    @stream.destroy()

  flush: ->
    # Tell the `@stream` to resume
    try
      @stream.resume()
    catch error
      # Stream is probably closed now

    # Flush the event buffer and re-emit the events.
    for [fun, args...] in @_queue
      switch fun
        when 'emit'
          @emit args...

    @_flushed = true

    # Emit a `drain` event to signal the buffer is empty.
    @emit 'drain'

# **BufferedWriteStream** wraps any writeable stream and captures writes
# to it. The data is held in a buffer until `flush` is called.
#
#     bufferedStream = new BufferWriteStream stream
#     stream.on 'connect', () -> bufferedStream.flush()
#     bufferedStream.write "foo"
#
exports.BufferedWriteStream = class BufferedWriteStream extends EventEmitter
  constructor: (@stream) ->
    @writeable = true
    @_queue = []
    @_flushed = false

    # Forward `drain`, `error` and `close` events
    @stream.on 'drain', => @emit 'drain'
    @stream.on 'error', (exception) => @emit 'error', exception

  # Call `write` on `@stream`, otherwise queue a `write` call.
  write: (args...) ->
    if @_flushed
      @stream.write args...
    else
      @_queue.push ['write', args...]
      false

  # Call `end` on `@stream`, otherwise queue a `end` call.
  end: (args...) ->
    if @_flushed
      @stream.end args...
    else
      @_queue.push ['end', args...]
      false

  # Call `destroy` on `@stream`, otherwise queue a `destroy` call.
  destroy: ->
    if @_flushed
      @stream.destroy()
    else
      @_queue.push ['destroy']
      false


  flush: ->
    # Process queued method calls
    for [fun, args...] in @_queue
      switch fun
        when 'write'
          @stream.write args...
        when 'end'
          @stream.end args...
        when 'destroy'
          @stream.destroy args...

    @_flushed = true

    # Emit a `drain` event to signal the buffer is empty.
    @emit 'drain'

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
