process = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

exports.testCreateProcess = (test) ->
  test.expect 5

  p = process.createProcess config
  test.ok p.sock
  test.ok p.child

  p.on 'ready', () ->
    test.ok true

    p.quit()
    p.on 'exit', () ->
      test.ok !p.sock
      test.ok !p.child

      test.done()
