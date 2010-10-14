{EventEmitter} = require 'events'

{BufferedReadStream,
 BufferedLineStream} = require 'nack/buffered'

class MockReadBuffer extends EventEmitter
  constructor: ->
    @readable = true
    @paused = false

  pause: ->
    @paused = true

  resume: ->
    @paused = false

  destroy: ->

exports.testBufferedReadStream = (test) ->
  test.expect 4

  buffer = new MockReadBuffer

  stream = new BufferedReadStream buffer
  test.ok stream.readable

  buffer.emit 'data', new Buffer("foo")

  stream.on 'data', (chunk) ->
    test.ok chunk

  stream.on 'end', ->
    test.ok true

  stream.flush()

  buffer.emit 'data', new Buffer("bar")
  buffer.emit 'end'

  test.done()

exports.testBufferedReadStreamEndsBeforeFlush = (test) ->
  test.expect 4

  buffer = new MockReadBuffer

  stream = new BufferedReadStream buffer
  test.ok stream.readable

  buffer.emit 'data', new Buffer("foo")
  buffer.emit 'data', new Buffer("bar")
  buffer.emit 'end'

  stream.on 'data', (chunk) ->
    test.ok chunk

  stream.on 'end', ->
    test.ok true

  stream.flush()

  test.done()

exports.testBufferedLineStream = (test) ->
  test.expect 5

  buffer = new MockReadBuffer

  stream = new BufferedLineStream buffer
  test.ok stream.readable

  lines = []
  stream.on 'data', (chunk) ->
    lines.push chunk

  stream.on 'end', ->
    test.ok true

  buffer.emit 'data', new Buffer("foo\n")
  test.same ["foo"], lines

  buffer.emit 'data', new Buffer("ba")
  test.same ["foo"], lines

  buffer.emit 'data', new Buffer("r\n")
  test.same ["foo", "bar"], lines

  buffer.emit 'end'

  test.done()
