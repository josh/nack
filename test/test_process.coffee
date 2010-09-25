http = require 'http'

{createProcess} = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

exports.testCreateProcess = (test) ->
  test.expect 10

  process = createProcess config
  process.on 'spawn', ->
    test.ok true

  process.on 'spawning', ->
    test.ok true

  process.on 'spawn', ->
    test.ok process.sockPath
    test.ok process.child

    test.ok process.stdout
    test.ok process.stderr

    process.stdout.on 'data', ->
      test.ok true

  process.onNext 'ready', ->
    test.ok true

    process.quit()
    process.on 'exit', ->
      test.ok !process.sockPath
      test.ok !process.child

      test.done()

  process.spawn()

exports.testProxyRequest = (test) ->
  test.expect 7

  process = createProcess config

  process.onNext 'ready', ->
    test.ok true

  process.on 'exit', ->
    test.ok true
    test.done()

  server = http.createServer (req, res) ->
    process.onNext 'busy', ->
      test.ok true

    process.onNext 'ready', ->
      test.ok true

    process.proxyRequest req, res, ->
      test.ok true
      process.quit()

  server.on 'close', ->
    test.ok true

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok !err
      server.close()

exports.testQuitSpawned = (test) ->
  test.expect 3

  process = createProcess config
  process.on 'spawn', ->
    test.ok true

  process.onNext 'ready', ->
    test.ok true

    process.on 'exit', ->
      test.ok true
      test.done()

    process.quit()

  process.spawn()

exports.testQuitUnspawned = (test) ->
  test.expect 1

  process = createProcess config

  process.on 'exit', ->
    test.ok true
    test.done()

  process.quit()
