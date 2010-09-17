{EventEmitter} = require 'events'

exports.BufferedStream = class BufferedStream extends EventEmitter
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

  destroy: (args...) ->
    if @_flushed
      @stream.destroy
    else
      @_queue.push ['destroy', args...]
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
