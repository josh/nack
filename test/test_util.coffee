{EventEmitter} = require 'events'

{LineBuffer} = require 'nack/util'

class MockReadBuffer extends EventEmitter
  constructor: ->
    @readable = true
    @paused = false

  pause: ->
    @paused = true

  resume: ->
    @paused = false

  destroy: ->

exports.testLineBuffer = (test) ->
  test.expect 5

  buffer = new MockReadBuffer

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
