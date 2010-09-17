client  = require 'nack/client'
process = require 'nack/process'

config = __dirname + "/fixtures/echo.ru"

exports.testClientRequest = (test) ->
  test.expect 5

  p = process.createProcess config
  p.on 'ready', () ->
    c = client.createConnection p.sockPath
    test.ok c

    request = c.request 'GET', '/foo', {}
    test.ok request

    request.end()

    request.on "response", (response) ->
      test.ok response
      test.same 200, response.statusCode

      p.quit()
      p.on 'exit', () ->
        test.ok true
        test.done()
