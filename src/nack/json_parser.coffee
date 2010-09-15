{EventEmitter} = require 'events'

CRLF = "\r\n"

exports.Stream = (client) ->
  stream = new EventEmitter()
  buffer = ""

  client.addListener "data", (chunk) ->
    buffer += chunk

    while (index = buffer.indexOf(CRLF)) != -1
      json   = buffer[0...index]
      buffer = buffer[index+CRLF.length...buffer.length]

      stream.emit 'obj', JSON.parse(json)

  stream
