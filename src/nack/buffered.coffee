{EventEmitter} = require 'events'

exports.BufferedReadStream = class BufferedReadStream extends EventEmitter
  constructor: (@stream) ->
    @readable = true
    @_queue = []
    @_flushed = false

    queueEvent = (event, args...) =>
      if @_flushed
        @emit args...
      else
        @_queue.push ['emit', event, args...]

    @stream.on 'data',  (args...) -> queueEvent 'data', args...
    @stream.on 'end',   (args...) -> queueEvent 'end', args...
    @stream.on 'error', (args...) -> queueEvent 'error', args...
    @stream.on 'close', (args...) -> queueEvent 'close', args...
    @stream.on 'fd',    (args...) -> queueEvent 'fd', args...

    @stream.pause()

    for all name, fun of @stream when !this[name] and name[0] != '_'
      @__defineGetter__ name, (args...) -> @stream[name]

  resume: () ->

  pause: () ->

  flush: () ->
    try
      @stream.resume()
    catch error
      # Stream is probably closed now

    for [fun, args...] in @_queue
      switch fun
        when 'emit'
          @emit args...

    @_flushed = true
    @emit 'drain'

exports.BufferedWriteStream = class BufferedWriteStream extends EventEmitter
  constructor: (@stream) ->
    @writeable = true
    @_queue = []
    @_flushed = false

    @stream.on 'drain', () => @emit 'drain'
    @stream.on 'error', (exception) => @emit 'error', exception
    @stream.on 'close', () => @emit 'close'

  write: (args...) ->
    if @_flushed
      @stream.write args...
    else
      @_queue.push ['write', args...]
      false

  end: (args...) ->
    if @_flushed
      @stream.end args...
    else
      @_queue.push ['end', args...]
      false

  destroy: () ->
    if @_flushed
      @stream.destroy()
    else
      @_queue.push ['destroy']
      false

  flush: () ->
    for [fun, args...] in @_queue
      switch fun
        when 'write'
          @stream.write args...
        when 'end'
          @stream.end args...
        when 'destroy'
          @stream.destroy args...

    @_flushed = true
    @emit 'drain'
