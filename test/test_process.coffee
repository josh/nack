{createProcess} = require 'nack/process'

config = __dirname + "/fixtures/hello.ru"

exports.testCreateProcess = (test) ->
  test.expect 5

  process = createProcess config
  process.spawn()

  test.ok process.sockPath
  test.ok process.child

  process.on 'ready', () ->
    test.ok true

    process.quit()
    process.on 'exit', () ->
      test.ok !process.sockPath
      test.ok !process.child

      test.done()
