events     = require 'events'
jsonParser = require 'nack/json_parser'

exports.testJsonParse = (test) ->
  test.expect 3

  rawStream  = new events.EventEmitter
  jsonStream = new jsonParser.Stream rawStream

  count = 0
  jsonStream.on "obj", (obj) ->
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
