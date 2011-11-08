{Stream} = require 'stream'

if process.env.NODE_DEBUG and /nack/.test process.env.NODE_DEBUG
  debug = exports.debug = (args...) -> console.error 'NACK:', args...
else
  debug = exports.debug = ->

# Is a given value a function?
exports.isFunction = (obj) ->
  if obj and obj.constructor and obj.call and obj.apply then true else false

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

class exports.BufferedPipe extends Stream
  constructor: ->
    @writable = true
    @readable = true

    @_queue = []
    @_ended = false

  write: (chunk, encoding) ->
    if @_queue
      debug "queueing #{chunk.length} bytes"
      @_queue.push [chunk, encoding]
    else
      debug "writing #{chunk.length} bytes"
      @emit 'data', chunk, encoding

    return

  end: (chunk, encoding) ->
    if chunk
      @write chunk, encoding

    if @_queue
      @_ended = true
    else
      debug "closing connection"
      @emit 'end'

    return

  destroy: ->
    @writable = false

  flush: ->
    return unless @_queue

    while @_queue and @_queue.length
      [chunk, encoding] = @_queue.shift()
      debug "writing #{chunk.length} bytes"
      @emit 'data', chunk, encoding

    if @_ended
      debug "closing connection"
      @emit 'end'

    @_queue = null

    return

class exports.BufferedRequest extends exports.BufferedPipe
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
