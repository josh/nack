http = require 'http'

{createProcess} = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

exports.testCreateProcess = (test) ->
  test.expect 9

  process = createProcess config
  process.on 'spawn', () ->
    test.ok true

  process.spawn()

  test.ok process.sockPath
  test.ok process.child

  test.ok process.stdout
  test.ok process.stderr

  process.stdout.on 'data', () ->
    test.ok true

  process.onNext 'ready', () ->
    test.ok true

    process.quit()
    process.on 'exit', () ->
      test.ok !process.sockPath
      test.ok !process.child

      test.done()

exports.testProxyRequest = (test) ->
  test.expect 5

  process = createProcess config

  process.onNext 'ready', () ->
    test.ok true

  process.on 'exit', () ->
    test.ok true
    test.done()

  server = http.createServer (req, res) ->
    process.proxyRequest req, res, () ->
      test.ok true
      process.quit()

  server.on 'close', () ->
    test.ok true

  server.listen PORT
  server.on 'listening', () ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok !err
      server.close()
