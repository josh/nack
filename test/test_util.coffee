{EventEmitter} = require 'events'

{LineBuffer, BufferedPipe} = require '../lib/util'

exports.testLineBuffer = (test) ->
  buffer = new EventEmitter

  stream = new LineBuffer buffer
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

exports.testBufferedPipe = (test) ->
  buffer = new BufferedPipe
  test.ok buffer.writable
  test.ok buffer.readable

  data = []
  buffer.on 'data', (chunk) ->
    data.push chunk

  buffer.write "1"
  test.same [], data

  buffer.write "2"
  test.same [], data

  buffer.flush()
  test.same ["1", "2"], data

  buffer.write "3"
  test.same ["1", "2", "3"], data

  test.done()

exports.testBufferedPipePiping = (test) ->
  buf1 = new BufferedPipe
  buf2 = new BufferedPipe
  buf3 = new BufferedPipe

  buf1.pipe buf2
  buf2.pipe buf3

  data = []
  buf3.on 'data', (chunk) ->
    data.push chunk

  buf1.write "1"
  test.same [], data

  buf1.write "2"
  test.same [], data

  buf1.flush()
  test.same [], data

  buf2.flush()
  test.same [], data

  buf3.flush()
  test.same ["1", "2"], data

  buf1.write "3"
  test.same ["1", "2", "3"], data

  test.done()
