{EventEmitter} = require 'events'

CRLF = "\r\n"

exports.StreamParser = class StreamParser extends EventEmitter
  constructor: (stream) ->
    buffer = ""

    stream.on 'data', (chunk) =>
      buffer += chunk

      while (index = buffer.indexOf(CRLF)) != -1
        json   = buffer[0...index]
        buffer = buffer[index+CRLF.length...buffer.length]

        @emit 'obj', JSON.parse(json)
