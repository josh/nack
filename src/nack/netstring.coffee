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
    -1
  else
    len

exports.nsLength = (buf) ->
  length   = buf.length
  nsHeader = "#{length}:"
  nsHeader.length + length + 1

exports.decode = (buffer) ->
  if typeof buffer is 'string'
    buffer = new Buffer buffer

  length = exports.length buffer

  if length is -1
    return -1

  nsHeader = "#{length}:"
  offset = nsHeader.length
  end    = offset+length

  if buffer.length < end
    -1
  else
    buffer.slice offset, end

exports.encode = (buffer) ->
  if typeof buffer is 'string'
    buffer = new Buffer buffer

  length   = buffer.length
  nsHeader = "#{length}:"
  nsLength = nsHeader.length + length + 1

  out = new Buffer nsLength
  out.write nsHeader, 0
  buffer.copy out, nsHeader.length, 0
  out.write ",", nsLength - 1
  out


{EventEmitter} = require 'events'

concatBuffers = (buf1, buf2) ->
  len = buf1.length + buf2.length
  buf = new Buffer len
  buf1.copy buf, 0, 0
  buf2.copy buf, buf1.length, 0
  buf

exports.ReadStream = class ReadStream extends EventEmitter
  constructor: (@stream) ->
    buffer = new Buffer 0

    @stream.on 'data', (chunk) =>
      buffer = concatBuffers buffer, chunk

      loop
        try
          buf = exports.decode buffer
          break if buf is -1
          offset = exports.nsLength buf
          buffer = buffer.slice offset, buffer.length
          @emit 'string', buf
        catch error
          @emit 'error', error
          break

    for all name, fun of @stream when !this[name] and name[0] != '_'
      @__defineGetter__ name, (args...) -> @stream[name]
