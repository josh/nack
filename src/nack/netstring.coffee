# Adapted from Peter Griess's node-netstring
# http://github.com/pgriess/node-netstring

exports.length = (buf) ->
  len = i = 0

  while i < buf.length
    byte = buf[i]

    if byte == 0x3a
      if i is 0
        throw new Error "Invalid netstring with leading ':'"
      else
        return len

    if byte < 0x30 or byte > 0x39
      throw new Error "Unexpected character '#{String.fromCharCode buf[i]}' found at offset #{i}"

    if len == 0 and i > 0
      throw new Error "Invalid netstring with leading 0"

    len = len * 10 + byte - 0x30

    i++

  if i is buf.length
    false
  else
    len

exports.decode = (buffer) ->
  if typeof buffer is 'string'
    buffer = new Buffer buffer

  len = exports.length buffer

  if len is false
    return false

  offset = "#{len}:".length
  end    = offset+len

  if buffer.length < end
    false
  else
    buffer[offset...end]

exports.encode = (buffer) ->
  new Buffer "#{buffer.length}:#{buffer},"


{EventEmitter} = require 'events'

exports.ReadStream = class ReadStream extends EventEmitter
  constructor: (@stream) ->
    for all name, fun of @stream when !this[name] and name[0] != '_'
      @__defineGetter__ name, (args...) -> @stream[name]

  on: (event, listener) ->
    if event is 'data'
      buffer = ""
      @stream.on 'data', (chunk) ->
        buffer += chunk

        while buf = exports.decode buffer
          offset = exports.encode(buf).length
          buffer = buffer[offset...offset+buffer.length]
          listener buf
    else
      @stream.on event, listener
