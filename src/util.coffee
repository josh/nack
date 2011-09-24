{Stream} = require 'stream'

if process.env.NODE_DEBUG and /nack/.test process.env.NODE_DEBUG
  debug = exports.debug = (args...) -> console.error 'NACK:', args...
else
  debug = exports.debug = ->

# Is a given value a function?
exports.isFunction = (obj) ->
  if obj and obj.constructor and obj.call and obj.apply then true else false

# Pauses Event Emitter
#
# Hack for http.ServerRequest#pause
#
# ry says it will be fixed soonish
exports.pause = (stream) ->
  unless stream._pausable
    # Patch this stream object to make it nicely pausable
    stream._pausable =
      pauses: 0
      events: ['data', 'end']
      queue:  []
      emit:   stream.emit
      pause:  -> stream._pausable.pauses++
      resume: ->
        if stream._pausable.pauses > 0
          stream._pausable.pauses--

          # No more pauses: empty the queue
          if stream._pausable.pauses == 0
            stream.emit args... for args in stream._pausable.queue
            stream._pausable.queue = []

    # Override stream.emit to emulate pausing
    stream.emit = (event, args...) ->
      if stream._pausable.pauses > 0 and event in stream._pausable.events
        stream._pausable.queue.push [event, args...]
      else
        args.unshift event
        stream._pausable.emit.apply stream, args

  stream._pausable.pause()

  onClose = -> removeListeners()
  stream.on 'close', onClose

  removeListeners = ->
    stream.removeListener 'close', onClose

  ->
    removeListeners()
    stream._pausable.resume()

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

class exports.BufferedReadStream extends Stream
  constructor: ->
    @writeable = true

    @_writeQueue = []
    @_writeEnded = false

  assignSocket: (socket) ->
    debug "socket assigned, flushing request"
    @socket = @connection = socket
    @socket.emit 'pipe', this
    @_flush()

  detachSocket: (socket) ->
    @writeable = false
    @socket = @connection = null

  write: (chunk, encoding) ->
    if @_writeQueue
      debug "queueing #{chunk.length} bytes"
      @_writeQueue.push [chunk, encoding]
      # Return false because data was buffered
      false
    else if @socket
      debug "writing #{chunk.length} bytes"
      @socket.write chunk, encoding

  # Closes writting socket.
  end: (chunk, encoding) ->
    if (chunk)
      @write chunk, encoding

    flushed = if @_writeQueue
      debug "queueing close"
      @_writeEnded = true
      # Return false because data was buffered
      false
    else if @socket
      debug "closing connection"
      @socket.end()

    @detachSocket @socket

    flushed

  destroy: ->
    @detachSocket @socket
    @socket.destroy()

  _flush: ->
    while @_writeQueue and @_writeQueue.length
      [chunk, encoding] = @_writeQueue.shift()
      debug "flushing #{chunk.length} bytes"
      @connection.write chunk, encoding

    if @_writeEnded
      debug "closing connection"
      @socket.end()

    @_writeQueue = null

    @emit 'drain'

    true

class exports.BufferedRequest extends exports.BufferedReadStream
  constructor: (@method, @url, @headers = {}, @proxyMetaVariables = {}) ->
    super

    # If another HttpRequest pipe is started, copy over its meta variables
    @once 'pipe', (src) =>
      @method ?= src.method
      @url    ?= src.url

      for key, value of src.headers
        @headers[key] ?= value

      for key, value of src.proxyMetaVariables
        @proxyMetaVariables[key] ?= value

      @proxyMetaVariables['REMOTE_ADDR'] ?= "#{src.connection?.remoteAddress}"
      @proxyMetaVariables['REMOTE_PORT'] ?= "#{src.connection?.remotePort}"
