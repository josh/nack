{EventEmitter}   = require 'events'
{BufferedStream} = require 'nack/buffered_stream'

class MockWriteBuffer extends EventEmitter
  constructor: () ->
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

  destroy: () ->

  getSize: () ->
    @buffer.length

exports.testBufferedStream = (test) ->
  test.expect 9

  buffer = new MockWriteBuffer

  stream = new BufferedStream buffer
  test.ok stream.writeable

  test.same false, stream.write 'foo', 'utf8'
  test.same false, stream.write new Buffer('bar')
  test.same 0, buffer.getSize()

  stream.on 'drain', () ->
    test.ok true

  stream.flush()
  test.same 2, buffer.getSize()

  stream.on 'drain', () ->
    test.ok false

  test.same true, stream.write 'baz'
  test.same 3, buffer.getSize()

  test.same true, stream.end()

  test.done()

exports.testBufferedStreamEndBeforeFlush = (test) ->
  test.expect 5

  buffer = new MockWriteBuffer

  stream = new BufferedStream buffer
  test.ok stream.writeable

  stream.on 'drain', () ->
    test.ok true

  test.same false, stream.end('foo')
  test.same 0, buffer.getSize()

  stream.flush()
  test.same 1, buffer.getSize()

  test.done()
