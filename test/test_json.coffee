{EventEmitter} = require 'events'
{StreamParser} = require 'nack/json'

exports.testJsonStreamParser = (test) ->
  test.expect 3

  rawStream  = new EventEmitter
  jsonStream = new StreamParser rawStream

  count = 0
  jsonStream.on 'obj', (obj) ->
    if count == 0
      test.same "200", obj
    else if count == 1
      test.same { foo: "bar" }, obj
    else if count == 2
      test.same "Hello", obj
    else
      test.ok false, "flunk"

    count++

  rawStream.emit 'data', '"200"\r\n'
  rawStream.emit 'data', '{"foo": "bar"}'
  rawStream.emit 'data', '\r\n'
  rawStream.emit 'data', '"Hel'
  rawStream.emit 'data', 'lo"\r\n'

  test.done()
