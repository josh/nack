# Pauses Event Emitter
#
# Hack for http.ServerRequest#pause
#
# ry says it will be fixed soonish
exports.pause = (stream) ->
  queue = []

  stream.pause()
  stream.on 'data', (args...) -> queue.push ['data', args...]
  stream.on 'end',  (args...) -> queue.push ['end', args...]

  () ->
    for args in queue
      stream.emit args...
    stream.resume()
