client  = require 'nack/client'
process = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

exports.testClientRequest = (test) ->
  test.expect 14

  p = process.createProcess config
  p.on 'ready', () ->
    c = client.createConnection p.sockPath
    test.ok c

    request = c.request 'GET', '/foo', {}
    test.ok request
    test.same "GET", request.method
    test.same "/foo", request.path
    test.same "/foo", request.headers['PATH_INFO']

    test.ok request.writeable

    request.end()

    request.on 'close', () ->
      test.ok true

    request.on 'response', (response) ->
      test.ok response
      test.same 200, response.statusCode
      test.equals c, response.client

      body = ""
      response.on 'data', (chunk) ->
        test.ok true
        body += chunk

      response.on 'end', () ->
        test.same "Hello World\n", body

        p.quit()
        p.on 'exit', () ->
          test.ok true
          test.done()
