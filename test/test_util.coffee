{EventEmitter} = require 'events'

{LineBuffer, pause} = require '../lib/util'

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

exports.testPauseAndResume = (test) ->
  test.expect 9

  chunks = ['chunk 1', 'chunk 2']
  stream = new EventEmitter

  badData  = (chunk) -> test.ok false, "'data' should not fire on paused streams, but received a chunk: #{chunk}"
  goodData = (chunk) -> test.ok true
  onEnd    = -> test.ok true
  dataConsumer = (chunk) ->
    index = chunks.indexOf chunk
    test.ok index > -1, "unexpected data chunk: #{chunk}"
    chunks[index..index] = [] if index > -1

  stream.on 'data', badData
  stream.on 'data', dataConsumer
  stream.on 'end',  onEnd

  resume1 = pause stream
  resume2 = pause stream
  resume3 = pause stream

  stream.emit 'data', chunk for chunk in chunks

  resume2?()

  chunks.push 'chunk 3'
  stream.emit 'data', 'chunk 3'

  stream.removeListener 'data', badData
  stream.on 'data', goodData

  chunks.push 'chunk 4'
  stream.emit 'data', 'chunk 4'
  stream.emit 'end'

  resume1?()
  resume3?()
  test.done()
