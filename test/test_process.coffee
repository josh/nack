fs   = require 'fs'
http = require 'http'

{createProcess} = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

PORT = 8080

fileExist = (path) ->
  try
    fs.statSync path
  catch exception
    false

exports.testCreateProcess = (test) ->
  test.expect 12

  sockPath = pipePath = null

  process = createProcess config

  process.on 'spawning', ->
    test.ok true

  process.on 'spawn', ->
    test.ok process.sockPath
    test.ok process.pipePath

    sockPath = process.sockPath
    pipePath = process.pipePath

    test.ok process.child
    test.ok process.stdout
    test.ok process.stderr

  process.once 'ready', ->
    test.ok true

    process.quit()
    process.on 'exit', ->
      test.ok !process.sockPath
      test.ok !process.pipePath

      test.ok !fileExist(sockPath)
      test.ok !fileExist(pipePath)

      test.ok !process.child

      test.done()

  process.spawn()

exports.testCreateConnection = (test) ->
  test.expect 6

  process = createProcess config

  process.once 'ready', ->
    test.ok true

  process.on 'exit', ->
    test.ok true
    test.done()

  process.createConnection (client) ->
    test.ok client

    request = client.request 'GET', '/foo', {}
    request.end()

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode

      body = ""
      response.on 'data', (chunk) ->
        body += chunk

      response.on 'end', ->
        test.same "Hello World\n", body

        process.quit()

exports.testCreateMultipleConnections = (test) ->
  test.expect 8

  process = createProcess config

  process.once 'ready', ->
    test.ok true

  process.on 'exit', ->
    test.ok true
    test.done()

  count = 2
  quit = ->
    count--
    if count is 0
      process.quit()

  openConnections = 0

  process.createConnection (client) ->
    openConnections++
    client.on 'close', -> openConnections--
    test.same 1, openConnections

    test.ok client
    request = client.request 'GET', '/foo', {}
    request.end()

    request.on 'response', (response) ->
      test.ok response
      response.on 'end', -> quit()

  process.createConnection (client) ->
    openConnections++
    client.on 'close', -> openConnections--
    test.same 1, openConnections

    test.ok client
    request = client.request 'GET', '/bar', {}
    request.end()

    request.on 'response', (response) ->
      test.ok response
      response.on 'end', -> quit()

exports.testCreateConnectionWithClientException = (test) ->
  test.expect 5

  process = createProcess "#{__dirname}/fixtures/error.ru"

  process.once 'ready', ->
    test.ok true

  process.on 'exit', ->
    test.ok true
    test.done()

  process.createConnection (client) ->
    test.ok client

    client.on 'close', ->
      process.quit()

    client.on 'error', (exception) ->
      test.ok exception

    request = client.request 'GET', '/', {}
    test.ok request
    request.end()

exports.testProxyRequest = (test) ->
  test.expect 6

  process = createProcess config

  process.once 'ready', ->
    test.ok true

  process.on 'exit', ->
    test.ok true
    test.done()

  server = http.createServer (req, res) ->
    server.close()

    process.once 'busy', ->
      test.ok true

    process.once 'ready', ->
      test.ok true

    process.proxyRequest req, res, ->
      test.ok true
      process.quit()

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ifError err

exports.testProxyRequestWithClientException = (test) ->
  test.expect 6

  process = createProcess "#{__dirname}/fixtures/error.ru"

  process.once 'ready', ->
    test.ok true

  process.on 'exit', ->
    test.ok true
    test.done()

  server = http.createServer (req, res) ->
    server.close()

    process.once 'busy', ->
      test.ok true

    process.once 'ready', ->
      test.ok true

    process.proxyRequest req, res, (err) ->
      test.ok err
      res.end()
      process.quit()

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok err

exports.testTerminate = (test) ->
  test.expect 3

  process = createProcess config

  process.once 'ready', ->
    test.ok true
    process.terminate()

  process.once 'quitting', () ->
    test.ok true

  process.on 'error', (error) ->
    test.ifError error

  process.once 'exit', ->
    test.ok true
    test.done()

  process.spawn()

exports.testQuitSpawned = (test) ->
  test.expect 4

  process = createProcess config

  process.on 'spawn', ->
    test.ok true

  process.once 'ready', ->
    test.ok true
    process.quit()

  process.once 'quitting', ->
    test.ok true

  process.on 'error', (error) ->
    test.ifError error

  process.once 'exit', ->
    test.ok true
    test.done()

  process.spawn()

exports.testQuitUnspawned = (test) ->
  test.expect 0

  process = createProcess config

  process.once 'quitting', ->
    test.ok false

  process.on 'error', (error) ->
    test.ifError error

  process.on 'exit', ->
    test.ok false

  process.quit()
  test.done()

exports.testRestart = (test) ->
  test.expect 3

  process = createProcess config

  process.once 'ready', ->
    process.on 'error', (error) ->
      test.ifError error

    process.once 'quitting', ->
      test.ok true

    process.on 'exit', ->
      test.ok true

    process.on 'ready', ->
      test.ok true
      test.done()

    process.restart()

  process.spawn()

exports.testErrorCreatingProcess = (test) ->
  test.expect 5

  process = createProcess __dirname + "/fixtures/crash.ru"

  process.on 'spawning', ->
    test.ok true

  process.on 'error', (error) ->
    test.same "b00m", error.message

  process.on 'exit', ->
    test.ok !process.sockPath
    test.ok !process.pipePath

    test.ok !process.child

    test.done()

  process.spawn()

exports.testErrorCreatingProcessOnConnection = (test) ->
  test.expect 2

  process = createProcess __dirname + "/fixtures/crash.ru"

  process.on 'error', (error) ->
    test.same "b00m", error.message

  process.on 'exit', ->
    test.ok true
    test.done()

  process.createConnection ->
    test.ok false

exports.testErrorCreatingProcessOnProxy = (test) ->
  test.expect 3

  process = createProcess __dirname + "/fixtures/crash.ru"

  process.on 'exit', ->
    test.ok true

  server = http.createServer (req, res) ->
    server.close()

    process.proxyRequest req, res, (err) ->
      test.ok err
      res.end()
      process.quit()

  server.listen PORT
  server.on 'listening', ->
    http.cat "http://127.0.0.1:#{PORT}/", "utf8", (err, data) ->
      test.ok err
      test.done()
