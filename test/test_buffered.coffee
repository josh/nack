{EventEmitter} = require 'events'
{BufferedReadStream, BufferedWriteStream} = require 'nack/buffered'

class MockReadBuffer extends EventEmitter
  constructor: ->
    @readable = true
    @paused = false

  pause: ->
    @paused = true

  resume: ->
    @paused = false

  destroy: ->

class MockWriteBuffer extends EventEmitter
  constructor: ->
    @writeable = true
    @buffer = []
    @ended = false

  write: (string) ->
    @buffer.push string
    true

  end: (string) ->
    @buffer.push string
    @ended = true
    true

  destroy: ->

  getSize: ->
    @buffer.length

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

exports.testBufferedWriteStream = (test) ->
  test.expect 9

  buffer = new MockWriteBuffer

  stream = new BufferedWriteStream buffer
  test.ok stream.writeable

  test.same false, stream.write 'foo', 'utf8'
  test.same false, stream.write new Buffer('bar')
  test.same 0, buffer.getSize()

  stream.on 'drain', ->
    test.ok true

  stream.flush()
  test.same 2, buffer.getSize()

  stream.on 'drain', ->
    test.ok false

  test.same true, stream.write 'baz'
  test.same 3, buffer.getSize()

  test.same true, stream.end()

  test.done()

exports.testBufferedWriteStreamEndBeforeFlush = (test) ->
  test.expect 5

  buffer = new MockWriteBuffer

  stream = new BufferedWriteStream buffer
  test.ok stream.writeable

  stream.on 'drain', ->
    test.ok true

  test.same false, stream.end('foo')
  test.same 0, buffer.getSize()

  stream.flush()
  test.same 1, buffer.getSize()

  test.done()
