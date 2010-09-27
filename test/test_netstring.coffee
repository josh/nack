{length, decode, encode} = require 'nack/netstring'

exports.testLength = (test) ->
  test.expect 6

  test.same 3, length new Buffer("3:abc,")
  test.same 0, length new Buffer("0:,")
  test.same false, length new Buffer("30")

  try
    length new Buffer(":")
  catch error
    test.same "Invalid netstring with leading ':'", error.message

  try
    length new Buffer("a:")
  catch error
    test.same "Unexpected character 'a' found at offset 0", error.message

  try
    length new Buffer("00:")
  catch error
    test.same "Invalid netstring with leading 0", error.message

  test.done()

exports.testDecode = (test) ->
  test.expect 5

  test.same decode("3:abc,"), new Buffer("abc")
  test.same decode(new Buffer("3:abc,")), new Buffer("abc")
  test.same decode("0:,"), new Buffer("")

  test.same decode("30"), false
  test.same decode("30:abc"), false

  test.done()

exports.testEncode = (test) ->
  test.expect 5

  test.same encode("abc"), new Buffer("3:abc,")
  test.same encode(new Buffer("abc", 'utf8')), new Buffer("3:abc,")
  test.same encode("a"), new Buffer("1:a,")
  test.same encode("hello world!"), new Buffer("12:hello world!,")
  test.same encode(""), new Buffer("0:,")

  test.done()


{EventEmitter} = require 'events'
{ReadStream}   = require 'nack/netstring'

exports.testReadStream = (test) ->
  test.expect 1

  stream   = new EventEmitter
  nsStream = new ReadStream stream

  chunks = []
  nsStream.on 'data', (chunk) ->
    chunks.push chunk

  stream.emit 'data', new Buffer("3:abc,")
  stream.emit 'data', new Buffer("12:hello")
  stream.emit 'data', new Buffer(" world!,")
  stream.emit 'data', new Buffer("1:a,1:b,1:c,")

  test.same [
    new Buffer("abc"),
    new Buffer("hello world!"),
    new Buffer("a"),
    new Buffer("b"),
    new Buffer("c")
  ], chunks

  test.done()
